import 'package:flutter/widgets.dart';

// Desktop-only notification: request DesktopMainScreen to open article
class OpenArticleInPane extends Notification {
  final String channelId;
  final String articleId;
  OpenArticleInPane(this.channelId, this.articleId);
}

