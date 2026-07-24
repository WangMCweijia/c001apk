import 'package:flutter/material.dart';

import '../pages/app/app_page.dart' show AppMenuItem;
import '../pages/chat/chat_page.dart' show ChatMenuType;
import '../pages/feed/feed_page.dart' show FeedMenuItem;
import '../pages/search/search_result_page.dart'
    show SearchMenuType, SearchType, SearchSortType;
import '../pages/settings/settings_page.dart' show SettingsMenuItem;
import '../pages/topic/topic_page.dart' show TopicMenuItem, TopicSortType;
import '../pages/user/user_page.dart' show UserMenuItem;
import '../pages/webview/webview_page.dart' show WebviewMenuItem;

/// 菜单项中文映射：将各页面 PopupMenu 的 enum 显示为中文，替代原 `.name` 英文。
class MenuLabels {
  MenuLabels._();

  /// 通用菜单项（动态状态：未关注/已关注、未拉黑/已拉黑等）
  static String of(dynamic item) {
    if (item is WebviewMenuItem) return webview(item);
    if (item is TopicMenuItem) return topic(item);
    if (item is SearchMenuType) return searchMenu(item);
    if (item is SearchType) return searchType(item);
    if (item is SearchSortType) return searchSort(item);
    if (item is AppMenuItem) return app(item);
    if (item is SettingsMenuItem) return settings(item);
    if (item is ChatMenuType) return chat(item);
    if (item is UserMenuItem) return user(item);
    if (item is FeedMenuItem) return feed(item);
    if (item is TopicSortType) return topicSort(item);
    return item.toString().split('.').last;
  }

  // ===== Webview =====
  static String webview(WebviewMenuItem item) {
    switch (item) {
      case WebviewMenuItem.Refresh:
        return '刷新';
      case WebviewMenuItem.Copy:
        return '复制链接';
      case WebviewMenuItem.Open_In_Browser:
        return '在浏览器打开';
      case WebviewMenuItem.Clear_Cache:
        return '清除缓存';
      case WebviewMenuItem.Go_Back:
        return '返回上一页';
    }
  }

  // ===== Topic =====
  static String topic(TopicMenuItem item) {
    switch (item) {
      case TopicMenuItem.Copy:
        return '复制';
      case TopicMenuItem.Share:
        return '分享';
      case TopicMenuItem.Sort:
        return '排序';
      case TopicMenuItem.Follow:
        return '关注';
      case TopicMenuItem.Block:
        return '屏蔽';
    }
  }

  static String topicSort(TopicSortType item) {
    switch (item) {
      case TopicSortType.DEFAULT:
        return '默认';
      case TopicSortType.DATELINE:
        return '最新';
      case TopicSortType.HOT:
        return '最热';
    }
  }

  // ===== Search =====
  static String searchMenu(SearchMenuType item) {
    switch (item) {
      case SearchMenuType.Type:
        return '类型';
      case SearchMenuType.Sort:
        return '排序';
    }
  }

  static String searchType(SearchType item) {
    switch (item) {
      case SearchType.ALL:
        return '全部';
      case SearchType.FEED:
        return '动态';
      case SearchType.ARTICLE:
        return '文章';
      case SearchType.COOLPIC:
        return '酷图';
      case SearchType.COMMENT:
        return '评论';
      case SearchType.RATING:
        return '评分';
      case SearchType.ANSWER:
        return '回答';
      case SearchType.QUESTION:
        return '提问';
      case SearchType.VOTE:
        return '投票';
    }
  }

  static String searchSort(SearchSortType item) {
    switch (item) {
      case SearchSortType.DATELINE:
        return '最新';
      case SearchSortType.DEFAULT:
        return '默认';
      case SearchSortType.HOT:
        return '最热';
      case SearchSortType.REPLY:
        return '回复数';
      case SearchSortType.STRICT:
        return '严格';
    }
  }

  // ===== App =====
  static String app(AppMenuItem item) {
    switch (item) {
      case AppMenuItem.Copy:
        return '复制';
      case AppMenuItem.Share:
        return '分享';
      case AppMenuItem.Follow:
        return '关注';
      case AppMenuItem.Block:
        return '屏蔽';
    }
  }

  // ===== Settings =====
  static String settings(SettingsMenuItem item) {
    switch (item) {
      case SettingsMenuItem.Feedback:
        return '反馈';
      case SettingsMenuItem.About:
        return '关于';
    }
  }

  // ===== Chat =====
  static String chat(ChatMenuType item) {
    switch (item) {
      case ChatMenuType.Check:
        return '查看资料';
      case ChatMenuType.Block:
        return '屏蔽';
      case ChatMenuType.Report:
        return '举报';
    }
  }

  // ===== User =====
  static String user(UserMenuItem item) {
    switch (item) {
      case UserMenuItem.Copy:
        return '复制';
      case UserMenuItem.Share:
        return '分享';
      case UserMenuItem.Block:
        return '屏蔽';
      case UserMenuItem.Report:
        return '举报';
      case UserMenuItem.UserInfo:
        return '查看资料';
    }
  }

  // ===== Feed =====
  static String feed(FeedMenuItem item) {
    switch (item) {
      case FeedMenuItem.Copy:
        return '复制';
      case FeedMenuItem.Share:
        return '分享';
      case FeedMenuItem.Fav:
        return '收藏';
      case FeedMenuItem.Block:
        return '屏蔽';
      case FeedMenuItem.Report:
        return '举报';
    }
  }
}
