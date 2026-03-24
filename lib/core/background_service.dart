import 'package:workmanager/workmanager.dart';
import 'package:background_fetch/background_fetch.dart';
import 'dart:io';
import 'hive_helper.dart';
import '../network/packet_router.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: \$task");
    
    // Initialize DB/Hive for background context
    await HiveHelper.instance.init();
    
    // Logic for background mesh relay
    // E.g., read pending queue, try to ping discovered BLE neighbors, relay pending
    // final router = PacketRouter.instance; 
    // router.init("background");
    
    return Future.value(true);
  });
}

class BackgroundService {
  static final BackgroundService instance = BackgroundService._init();
  BackgroundService._init();

  Future<void> init() async {
    if (Platform.isAndroid) {
      // Setup Workmanager for Android background processing
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true,
      );
      
      // Register a periodic task
      await Workmanager().registerPeriodicTask(
        "offtalk_mesh_relay",
        "meshRelayTask",
        frequency: const Duration(minutes: 15), // Android minimum is 15 mins
        constraints: Constraints(
          networkType: NetworkType.not_required,
        ),
      );
      
      // Note: A true foreground service needs flutter_foreground_task for continuous BLE
      
    } else if (Platform.isIOS) {
      // Setup Background Fetch for iOS
      int status = await BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        stopOnTerminate: false,
        enableHeadless: true,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresNetworkConnectivity: false,
        requiresDeviceIdle: false,
      ), (String taskId) async {
        print("[BackgroundFetch] Event received \$taskId");
        
        await HiveHelper.instance.init();
        
        BackgroundFetch.finish(taskId);
      }, (String taskId) async {
        print("[BackgroundFetch] TASK TIMEOUT \$taskId");
        BackgroundFetch.finish(taskId);
      });
      
      print('[BackgroundFetch] configure success: \$status');
      BackgroundFetch.start();
    }
  }
}
