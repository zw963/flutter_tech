import 'package:flutter/material.dart';
import 'package:nativeshell/nativeshell.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: WindowWidget(
        onCreateState: (initData) {
          WindowState? state;
          state ??= MainWindowState();
          return state;
        },
      ),
    );
  }
}

class MainWindowState extends WindowState {
  @override
  WindowSizingMode get windowSizingMode =>
      WindowSizingMode.atLeastIntrinsicSize;

  @override
  Widget build(BuildContext context) {
    return MainWindow();
  }
}

class MainWindow extends StatefulWidget {
  const MainWindow();

  @override
  State<StatefulWidget> createState() {
    return _MainWindowState();
  }
}

class _MainWindowState extends State<MainWindow> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ExamplesWindow(child: WindowManagementPage());
  }
}

class WindowManagementPage extends StatefulWidget {
  const WindowManagementPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return WindowManagementPageState();
  }
}

// 下面的 Mixin 来自于 native_shell
class WindowManagementPageState extends State<WindowManagementPage>
    with WindowMethodCallHandlerMixin<WindowManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              TableRow(children: [SizedBox(height: 10), Container()]),
              TableRow(children: [
                otherWindow == null
                    ? TextButton(
                        onPressed: showOtherWindow,
                        child: Text('Show Other Window'),
                      )
                    : TextButton(
                        onPressed: closeOtherWindow,
                        child: Text('Hide Other Window'),
                      ),
                Row(children: [
                  SizedBox(
                    width: 10,
                  ),
                ]),
              ]),
            ]),
      ],
    );
  }

  Window? otherWindow;
  String? messageFromOtherWindow;

  void showOtherWindow() async {
    // use veil to prevent double events while waiting for window to initialize
    final window = await Window.create(OtherWindowState.toInitData());
    setState(() {
      otherWindow = window;
    });

    // get notification when user closes other window
    window.closeEvent.addListener(() {
      // when hiding window from dispose the close event will be fired, but
      // but at that point we're not mounted anymore
      if (mounted) {
        setState(() {
          otherWindow = null;
          messageFromOtherWindow = null;
        });
      }
    });
  }

  void closeOtherWindow() async {
    await otherWindow?.close();
    setState(() {
      otherWindow = null;
      messageFromOtherWindow = null;
    });
  }

  void callMethodOnOtherWindow() async {
    await otherWindow?.callMethod('showMessage', 'Hello from parent window!');
  }

  // handles method call on this window
  @override
  MethodCallHandler? onMethodCall(String name) {
    if (name == 'showMessage') {
      return showMessage;
    } else {
      return null;
    }
  }

  void showMessage(dynamic arguments) {
    setState(() {
      messageFromOtherWindow = arguments;
    });
  }

  @override
  void dispose() {
    otherWindow?.close();
    super.dispose();
  }
}

class OtherWindow extends StatefulWidget {
  const OtherWindow();

  @override
  State<StatefulWidget> createState() {
    return _OtherWindowState();
  }
}

class _OtherWindowState extends State<OtherWindow>
    with WindowMethodCallHandlerMixin<OtherWindow> {
  @override
  Widget build(BuildContext context) {
    // can't call Window.of(context) in initState
    if (firstBuild) {
      firstBuild = false;

      // Disable the button when parent window gets closed
      Window.of(context).parentWindow?.closeEvent.addListener(() {
        setState(() {});
      });
    }

    return Container(
      color: Colors.blueGrey.shade50,
      padding: EdgeInsets.all(20),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: Colors.black),
        child: Column(
          children: [
            TextButton(
              onPressed: Window.of(context).parentWindow != null
                  ? callMethodOnParentWindow
                  : null,
              child: Text(
                'Call method on parent window',
              ),
            ),
            if (messageFromParentWindow != null) ...[
              SizedBox(height: 15),
              Text('Parent window says:'),
              SizedBox(height: 5),
              Text('$messageFromParentWindow'),
            ]
          ],
        ),
      ),
    );
  }

  void callMethodOnParentWindow() async {
    await Window.of(context).parentWindow?.callMethod('showMessage', 'Hello');
  }

  bool firstBuild = true;

  String? messageFromParentWindow;

  @override
  MethodCallHandler? onMethodCall(String method) {
    if (method == 'showMessage') {
      return showMessage;
    } else {
      return null;
    }
  }

  void showMessage(dynamic message) {
    setState(() {
      messageFromParentWindow = message;
    });
  }
}

class OtherWindowState extends WindowState {
  @override
  Widget build(BuildContext context) {
    return ExamplesWindow(child: OtherWindow());
  }

  @override
  Future<void> initializeWindow(Size intrinsicContentSize) async {
    // If possible, show the window to the right of parent window
    Offset? origin;
    final parentGeometry = await window.parentWindow?.getGeometry();
    if (parentGeometry?.frameOrigin != null &&
        parentGeometry?.frameSize != null) {
      origin = parentGeometry!.frameOrigin!
          .translate(parentGeometry.frameSize!.width + 20, 0);
    }
    await window.setGeometry(Geometry(
      frameOrigin: origin,
      contentSize: intrinsicContentSize,
    ));
    await window.setStyle(WindowStyle(canResize: false));
    await window.show();
  }

  @override
  WindowSizingMode get windowSizingMode => WindowSizingMode.sizeToContents;

  static dynamic toInitData() => {
        'class': 'otherWindow',
      };

  static OtherWindowState? fromInitData(dynamic initData) {
    if (initData is Map && initData['class'] == 'otherWindow') {
      return OtherWindowState();
    }
    return null;
  }
}

// Common scaffold code used by each window
class ExamplesWindow extends StatelessWidget {
  const ExamplesWindow({Key? key, required this.child}) : super(key: key);

  final Widget child;

  // Window 开头的常量来自于 nativeshell.dart
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTextStyle(
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        child: WindowLayoutProbe(child: child),
      ),
    );
  }
}
