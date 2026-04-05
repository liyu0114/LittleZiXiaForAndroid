// 24点游戏入口界面 - 使用统一的房间系统
//
// 统一UI：单机模式 + 联网模式

import 'package:flutter/material.dart';
import '../widgets/room_entry_screen.dart';
import 'twenty_four_game_screen.dart';
import 'network_game_screen.dart';

class TwentyFourGameEntryScreen extends StatelessWidget {
  const TwentyFourGameEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoomEntryScreen(
      title: '24点游戏',
      icon: Icons.games,
      singlePlayerScreen: () => const TwentyFourGameScreen(),
      networkScreen: () => const NetworkGameScreen(),
    );
  }
}
