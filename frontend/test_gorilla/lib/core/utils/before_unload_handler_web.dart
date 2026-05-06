import 'dart:js' as js;

class BeforeUnloadHandler {
  static const _message =
      "All your progress will be lost. You will have to start again.";

  static void enableWarning() {
    js.context.callMethod('eval', [
      'window.onbeforeunload = function(e) { e.preventDefault(); e.returnValue = "$_message"; return "$_message"; };',
    ]);
  }

  static void disableWarning() {
    js.context.callMethod('eval', ['window.onbeforeunload = null;']);
  }
}
