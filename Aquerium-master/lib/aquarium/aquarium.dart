import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:aquarium/shark/enum.dart';
import 'package:aquarium/shark/shark.dart';
import 'package:aquarium/shark/shark_request.dart';
import 'package:uuid/uuid.dart';

import '../fish/fish.dart';
import '../fish/fish_action.dart';
import '../fish/fish_request.dart';
import '../fish/genders.dart';
import '../utils/fish_names.dart';
import 'fish_model.dart';

class Aquarium {
  final Random _random = Random();
  int sharkAte = 0;
  final LinkedHashMap<String, FishModel> _fishList = LinkedHashMap();
  final LinkedHashMap<String, FishModel> _sharkList = LinkedHashMap();
  final ReceivePort _mainReceivePort = ReceivePort();
  int _newFishCount = 0;
  int _diedFishCount = 0;

  void runApp() {
    stdout.write("Enter initial fish count: ");
    final int count = int.tryParse(stdin.readLineSync() ?? '0') ?? 0;
    portListener();
    initial(count);
  }

  void portListener() {
    _mainReceivePort.listen((value) {
      if (value is FishRequest) {
        switch (value.action) {
          case FishAction.sendPort:
            _fishList.update(
              value.fishId,
              (model) {
                (value.args as SendPort?)?.send(FishAction.startLife);
                return model.copyWith(
                  sendPort: (value.args as SendPort?),
                );
              },
            );
            break;
          case FishAction.fishDied:
            final model = _fishList[value.fishId];
            model?.sendPort?.send(FishAction.close);
            _diedFishCount++;
            break;
          case FishAction.killIsolate:
            killIsolate(value.fishId);

          case FishAction.needPopulate:
            population(value.fishId, value.args as Genders);
            break;
          default:
            break;
        }
      } else if (value is SharkRequest) {
        if (value.action == SharkAction.hunt) {
          hunt();
        }
      }
    });
  }

  void population(String fishId, Genders gender) {
    if (_fishList.isNotEmpty) {
      final sortFishList = _fishList.entries
          .where(
            (element) => element.value.genders != gender,
          )
          .toList();
      if (sortFishList.isNotEmpty) {
        final findIndex = _random.nextInt(sortFishList.length);
        final findFishId = sortFishList[findIndex].key;
        if (gender.isMale) {
          createFish(
            maleId: fishId,
            femaleId: findFishId,
          );
        } else {
          createFish(
            maleId: findFishId,
            femaleId: fishId,
          );
        }
      } else {
        closeAquarium();
      }
    }
  }

  void initial(int count) {
    for (int i = 0; i < count; i++) {
      createFish();
    }
    balancePopulation();
  }

  void createFish({
    String? maleId,
    String? femaleId,
  }) async {
    final fishId = Uuid().v1(options: {
      "Male": maleId,
      "Female": femaleId,
    });
    final gender = _random.nextBool() ? Genders.male : Genders.female;
    final firstName = gender.isMale
        ? FishNames.maleFirst[_random.nextInt(FishNames.maleFirst.length)]
        : FishNames.femaleFirst[_random.nextInt(FishNames.femaleFirst.length)];
    final lastName = gender.isMale
        ? FishNames.maleLast[_random.nextInt(FishNames.maleLast.length)]
        : FishNames.femaleLast[_random.nextInt(FishNames.femaleLast.length)];
    final lifespan = Duration(seconds: _random.nextInt(40) + 5);
    final populateCount = _random.nextInt(1) + 1;
    final List<Duration> listPopulationTime = List.generate(
      populateCount,
      (index) => Duration(seconds: _random.nextInt(15) + 5),
    );

    final fish = Fish(
      id: fishId,
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      lifespan: lifespan,
      listPopulationTime: listPopulationTime,
      sendPort: _mainReceivePort.sendPort,
    );
    final isolate = await Isolate.spawn(Fish.run, fish);
    _fishList[fishId] = FishModel(
      isolate: isolate,
      genders: gender,
    );
    _newFishCount++;
    print(toString());

    if (_fishList.length > 10) {
      hunt();
      sharkAte++;
    }
  }

  void closeAquarium() {
    print("Baliq qolmadi pupulatsiya nihoyasiga yetdi");
    print("Akula $sharkAte ta baliq yedi");
    exit(0);
  }

  @override
  String toString() {
    int fishCount = 0;
    int maleCount = 0;
    int femaleCount = 0;

    _fishList.forEach((key, value) {
      fishCount++;
      if (value.genders == Genders.male) {
        maleCount++;
      } else {
        femaleCount++;
      }
    });

    if (fishCount == 0) {
      closeAquarium();
    }
    // print('\x1B[2J\x1B[0;0H');
    return 'Aquarium info - Fish count: $fishCount, Male count: $maleCount, Female count: $femaleCount, New fish count: $_newFishCount, Died fish count: $_diedFishCount';
  }

  void balancePopulation() {
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (_fishList.length < 10) {
        int fishToAdd = 10 - _fishList.length;
        for (int i = 0; i < fishToAdd; i++) {
          createFish();
        }
      }
    });
  }

  void createShark() async {
    final sharkId = Uuid().v1();
    final huntInterval = Duration(seconds: _random.nextInt(20) + 5);
    final shark = Shark(
      id: sharkId,
      huntInterval: huntInterval,
      sendPort: _mainReceivePort.sendPort,
    );
    final isolate = await Isolate.spawn(Shark.run, shark);
    _sharkList[sharkId] = isolate as FishModel;
    print('Shark created with id: $sharkId and hunt interval: $huntInterval');
  }

  void hunt() {
    final randomHuntInterval = Duration(seconds: _random.nextInt(10) + 5);
    Timer.periodic(randomHuntInterval, (timer) {
      if (_fishList.length <= 10) {
        timer.cancel();
      } else {
        if (_fishList.isNotEmpty) {
          final fishIds = _fishList.keys.toList();
          final targetFishId = fishIds[_random.nextInt(fishIds.length)];
          killIsolate(targetFishId);
          _fishList.remove(targetFishId);
          print("Shark ate fish with id: $targetFishId");
          _diedFishCount++;
          print(toString());
        }
      }
    });
  }

  killIsolate(String fishId) {
    final model = _fishList[fishId];
    if (model != null) {
      model.isolate.kill(priority: Isolate.immediate);
      _fishList.remove(fishId);
      print(toString());
    }
  }
}
