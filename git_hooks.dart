import 'dart:io';
import 'dart:async';
import 'package:git_hooks/git_hooks.dart';

void main(List<String> arguments) {
  final hooks = {
    Git.commitMsg: _checkCommitMsg,
    Git.preCommit: _preCommit,
  };
  GitHooks.call(arguments, hooks);
}

/// 校验提交信息规范
Future<bool> _checkCommitMsg() async {
  print("🔍 检查提交信息规范...");
  final commitMsgFile = File('.git/COMMIT_EDITMSG');
  if (!commitMsgFile.existsSync()) return Future.value(true);

  final commitMsg = commitMsgFile.readAsStringSync().trim();
  final regex = RegExp(
    r'^(feat|fix|docs|style|refactor|test|chore|add)(\([^)]+\))?: .{1,100}$',
  );

  if (!regex.hasMatch(commitMsg)) {
    print('');
    print('❌ 提交信息不符合 Flutter 项目规范！');
    print('✅ 正确格式：类型(作用域): 描述');
    print('✅ 示例：');
    print('   feat(ui): 新增登录页面');
    print('   fix(bloc): 修复状态管理异常');
    print('   docs: 更新 README 部署说明');
    print('✅ 允许类型：feat/fix/docs/style/refactor/test/chore/adds');
    print('');
    return Future.value(false);
  }

  print('✅ 提交信息校验通过');
  return Future.value(true);
}

/// 提交前自动运行 flutter analyze（Windows 兼容版）
// Future<bool> _preCommit() async {
//   print('🔍 运行 flutter analyze 检查代码规范...');
  
//   // Windows 兼容处理
//   final isWindows = Platform.isWindows;
//   final flutterCmd = isWindows ? 'flutter.bat' : 'flutter';
//   final runInShell = isWindows; // Windows 上需要通过 shell 运行

//   try {
//     final result = await Process.run(
//       flutterCmd,
//       ['analyze'],
//       runInShell: runInShell,
//     );
    
//     if (result.exitCode != 0) {
//       print('❌ 代码规范检查不通过！');
//       print(result.stdout);
//       return Future.value(false);
//     }
    
//     print('✅ 代码规范检查通过');
//     return Future.value(true);
//   } catch (e) {
//     print('⚠️ 无法运行 flutter analyze，请检查 Flutter 是否在 PATH 中');
//     print('错误详情：$e');
//     // 如果只是找不到命令，可以选择放行（return true），或者阻止（return false）
//     return Future.value(true); 
//   }
// }

Future<bool> _preCommit() async {
  //暂时不校验，只弹出警告提醒flutter analyze，后续再添加代码规范，目前先校验正则,flutter analyze只是作为提醒
  print("🔍 检查代码规范...");
  //windows
  final flutterCmd = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final runInShell = Platform.isWindows; // Windows 上需要通过 shell 运行
  try {
      final result = await Process.run(
        flutterCmd,
        ['analyze'],
        runInShell: runInShell,
      );
      print(result.stdout);
      return Future.value(true);
    } catch (e) {
      print('⚠️ 无法运行 flutter analyze，请检查 Flutter 是否在 PATH 中');
      print('错误详情：$e');
      // 如果只是找不到命令，可以选择放行（return true），或者阻止（return false）
      return Future.value(true); 
  }
}