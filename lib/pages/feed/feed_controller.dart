import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../logic/model/fav_history/fav_history.dart';
import '../../logic/model/feed/datum.dart';
import '../../logic/model/feed/user_action.dart';
import '../../logic/model/feed_article/feed_article.dart';
import '../../logic/network/network_repo.dart';
import '../../logic/state/loading_state.dart';
import '../../pages/common/common_controller.dart';
import '../../pages/feed/feed_page.dart' show ReplySortType;
import '../../utils/extensions.dart';
import '../../utils/storage_util.dart';

class FeedController extends CommonController {
  FeedController({
    required this.id,
    required this.recordHistory,
    this.preloadedData,
  });
  final String id;
  final bool recordHistory;
  final Datum? preloadedData;

  String listType = 'lastupdate_desc';
  final int _discussMode = 1;
  final String _feedType = 'feed';
  final int _blockStatus = 0;
  int fromFeedAuthor = 0;

  String? feedTypeName;
  int? feedUid;
  String? feedUsername;
  int? replyNum;

  List<FeedArticle>? articleList;
  List<String>? articleImgList;

  Datum? topReply;
  Datum? _replyMe;

  Rx<LoadingState> feedState = LoadingState.loading().obs;
  bool isFav = false;
  bool isBlocked = false;

  Rx<ReplySortType> replySelection = ReplySortType.def.obs;

  void setFeedState(LoadingState feedState) {
    this.feedState.value = feedState;
  }

  @override
  Future<LoadingState> customGetData() {
    return NetworkRepo.getFeedReply(
      id: id,
      listType: listType,
      page: page,
      firstItem: firstItem,
      lastItem: lastItem,
      discussMode: _discussMode,
      feedType: _feedType,
      blockStatus: _blockStatus,
      fromFeedAuthor: fromFeedAuthor,
    );
  }

  /// 处理动态数据：解析 messageRawOutput、补充 picArr、提取字段
  void _processFeedData(Datum data) {
    debugPrint('[feedDetail] _processFeedData id=${data.id} hashCode=${hashCode} '
        'messageRawOutput=${data.messageRawOutput == null ? "null" : (data.messageRawOutput == "null" ? '"null"' : "有值(${data.messageRawOutput!.length}字符)")} '
        'message=${data.message == null ? "null" : (data.message!.isEmpty ? "空字符串" : "有值(${data.message!.length}字符)")} '
        'picArr=${data.picArr == null ? "null" : (data.picArr!.isEmpty ? "空数组" : "有${data.picArr!.length}张图")} '
        'articleListBefore=${articleList == null ? "null" : (articleList!.isEmpty ? "空数组" : "${articleList!.length}项")}');
    try {
      if (data.messageRawOutput != null && data.messageRawOutput != 'null') {
        debugPrint('[feedDetail] _processFeedData branch=if(messageRawOutput) id=${data.id}');
        List<dynamic> jsonList = jsonDecode(data.messageRawOutput!);
        articleList = jsonList
            .map((json) => FeedArticle.fromJson(json))
            .where((item) => ['text', 'image', 'shareUrl'].contains(item.type))
            .toList();
        if (!data.title.isNullOrEmpty) {
          String title = data.title!;
          final uname = data.userInfo?.username ?? data.username;
          if (uname != null && uname.isNotEmpty) {
            if (title == '$uname的动态' || title == '$uname: 动态') {
              title = '';
            } else if (title.startsWith('$uname的动态')) {
              title = title.substring('$uname的动态'.length).trim();
            } else if (title.startsWith('$uname: ')) {
              title = title.substring('$uname: '.length).trim();
            } else if (title.startsWith('$uname：')) {
              title = title.substring('$uname：'.length).trim();
            }
          }
          if (title.isNotEmpty) {
            articleList!.insert(0, FeedArticle(type: 'title', title: title));
          }
        }
        if (!data.messageCover.isNullOrEmpty) {
          articleList!
              .insert(0, FeedArticle(type: 'image', url: data.messageCover));
        }
        if (!data.message.isNullOrEmpty &&
            !articleList!.any((item) => item.type == 'text')) {
          articleList!.add(FeedArticle(type: 'text', message: data.message));
        }
        articleImgList = articleList!
            .where((item) => item.type == 'image')
            .map((item) => item.url.orEmpty)
            .toList();
        if (!data.picArr.isNullOrEmpty) {
          final existing = articleImgList!.toSet();
          for (var img in data.picArr!) {
            if (!existing.contains(img)) {
              articleList!.add(FeedArticle(type: 'image', url: img));
              articleImgList!.add(img);
            }
          }
        }
      } else {
        debugPrint('[feedDetail] _processFeedData branch=else(message+picArr) id=${data.id}');
        articleList = [];
        articleImgList = [];
        if (!data.message.isNullOrEmpty) {
          articleList!.add(FeedArticle(type: 'text', message: data.message));
        }
        if (!data.picArr.isNullOrEmpty) {
          for (var img in data.picArr!) {
            articleList!.add(FeedArticle(type: 'image', url: img));
            articleImgList!.add(img);
          }
        }
      }
      debugPrint('[feedDetail] _processFeedData before topReply id=${data.id} '
          'topReplyRows=${data.topReplyRows == null ? "null" : (data.topReplyRows!.isEmpty ? "空数组" : "有${data.topReplyRows!.length}项")} '
          'replyRows=${data.replyRows == null ? "null" : (data.replyRows!.isEmpty ? "空数组" : "有${data.replyRows!.length}项")}');
      if (!data.topReplyRows.isNullOrEmpty) {
        topReply = data.topReplyRows![0];
      } else if (topReply == null && !data.replyRows.isNullOrEmpty) {
        topReply = data.replyRows![0];
      }
      if (!data.replyMeRows.isNullOrEmpty) {
        _replyMe = data.replyMeRows![0];
      }
      feedUsername = data.userInfo?.username;
      feedUid = data.uid;
      feedTypeName = data.feedTypeName;
      replyNum = data.replynum;
      debugPrint('[feedDetail] _processFeedData done id=${data.id} hashCode=${hashCode} '
          'articleListAfter=${articleList == null ? "null" : (articleList!.isEmpty ? "空数组" : "${articleList!.length}项")}');
    } catch (e, stack) {
      debugPrint('[feedDetail] _processFeedData EXCEPTION id=${data.id} hashCode=${hashCode} error=$e\n$stack');
      // 异常时清空 articleList,让 onInit 的 canShowPreloaded=false 走网络加载
      articleList = null;
      articleImgList = null;
    }
  }

  Future<void> getFeedData() async {
    debugPrint('[feedDetail] getFeedData start id=$id hashCode=${hashCode} url=/v6/feed/detail?id=$id');
    try {
      LoadingState<dynamic> response =
          await NetworkRepo.getDataFromUrl(url: '/v6/feed/detail?id=$id');
      debugPrint('[feedDetail] getFeedData response id=$id hashCode=${hashCode} '
          'type=${response.runtimeType} '
          'isSuccess=${response is Success} '
          'isError=${response is Error} '
          'isEmpty=${response is Empty}');
      if (response is Success) {
        Datum data = (response.response as Datum);
        _processFeedData(data);
        onGetData();

        isFav = GStorage.checkFav(id);
        isBlocked = GStorage.checkUser(feedUid.toString());
        // todo: check
        if (recordHistory && !GStorage.checkHistory(id)) {
          GStorage.historyFeed.put(id, getFeed(data));
        }
      }
      feedState.value = response;
    } catch (e, stack) {
      debugPrint('[feedDetail] getFeedData EXCEPTION id=$id hashCode=${hashCode} error=$e\n$stack');
      feedState.value = LoadingState.error(e.toString());
    }
  }

  void onFav() {
    Datum data = (feedState.value as Success).response;
    GStorage.favFeed.put(id, getFeed(data));
  }

  FavHistoryItem getFeed(Datum data) {
    return FavHistoryItem(
      id: data.id.toString(),
      uid: data.uid.toString(),
      username: data.userInfo?.username,
      userAvatar: data.userInfo?.userAvatar,
      message: (data.message ?? '').length <= 150
          ? data.message
          : data.message!.substring(0, 150),
      device: data.deviceTitle,
      dateline: data.dateline.toString(),
      time: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  void onInit() {
    super.onInit();
    debugPrint('[feedDetail] onInit id=$id hashCode=${hashCode} '
        'preloadedData=${preloadedData == null ? "null(不预加载)" : "有(预加载)"} '
        'preloadedMessage=${preloadedData?.message == null ? "null" : (preloadedData!.message!.isEmpty ? "空字符串" : "有值")} '
        'preloadedPicArr=${preloadedData?.picArr == null ? "null" : (preloadedData!.picArr!.isEmpty ? "空数组" : "有${preloadedData!.picArr!.length}张图")} '
        'preloadedMessageRawOutput=${preloadedData?.messageRawOutput == null ? "null" : (preloadedData!.messageRawOutput == "null" ? '"null"字符串' : "有值")}');
    if (preloadedData != null) {
      _processFeedData(preloadedData!);
      // 只有预加载合成的 articleList 非空时才设置 Success,
      // 避免精简 Datum(message/picArr 都空)合成空 articleList 后
      // 渲染空白 FeedCard 导致白屏。
      // articleList 为空时保持 Loading,等 getFeedData() 返回完整数据
      // 后重新合成并渲染。
      final bool canShowPreloaded =
          articleList != null && articleList!.isNotEmpty;
      debugPrint('[feedDetail] onInit canShowPreloaded=$canShowPreloaded '
          'articleListSize=${articleList?.length ?? 0}');
      if (canShowPreloaded) {
        feedState.value = LoadingState.success(preloadedData!);
      }
      getFeedData();
    } else {
      getFeedData();
    }
  }

  void onBlockReply(dynamic uid, dynamic id) {
    List<Datum> replyList = (loadingState.value as Success).response;
    if (id != null) {
      replyList = replyList.map((reply) {
        if (reply.id == id) {
          return reply
            ..replyRows =
                reply.replyRows!.where((reply) => reply.uid != uid).toList();
        } else {
          return reply;
        }
      }).toList();
    } else {
      replyList = replyList.where((reply) => reply.uid != uid).toList();
    }
    loadingState.value = LoadingState.success(replyList);
  }

  @override
  List<Datum>? handleResponse(List<Datum> dataList) {
    List<Datum> filterList = dataList;
    if (page == 1 && listType == 'lastupdate_desc') {
      filterList = [
            if (topReply != null) topReply!,
            if (_replyMe != null) _replyMe!,
          ] +
          filterList;
    }
    List<String> userBlackList = GStorage.blackList
        .get(BlackListBoxKey.userBlackList, defaultValue: <String>[]);
    return filterList
        .map((data) => data
          ..replyRows = !data.replyRows.isNullOrEmpty
              ? data.replyRows!
                  .where(
                      (reply) => !userBlackList.contains(reply.uid.toString()))
                  .toList()
              : null)
        .toList();
  }

  void updateReply(bool isReply, Datum data, dynamic id, dynamic fid) {
    List<Datum> replyList = loadingState.value is Success
        ? (loadingState.value as Success).response
        : [];
    if (isReply) {
      replyList = replyList.map((reply) {
        if (reply.id == (fid ?? id)) {
          return reply..replyRows = (reply.replyRows ?? []) + [data];
        } else {
          return reply;
        }
      }).toList();
    } else {
      replyList.insert(topReply == null ? 0 : 1, data);
    }
    loadingState.value = LoadingState.success(replyList);
  }

  @override
  bool handleLike(dynamic like, dynamic likenum) {
    Datum data = (feedState.value as Success).response;
    feedState.value = LoadingState.success(data
      ..likenum = likenum
      ..userAction = UserAction(like: like == 1 ? 0 : 1));
    return true;
  }
}
