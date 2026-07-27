import 'dart:convert';

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
    if (data.messageRawOutput != null && data.messageRawOutput != 'null') {
      List<dynamic> jsonList = jsonDecode(data.messageRawOutput!);
      articleList = jsonList
          .map((json) => FeedArticle.fromJson(json))
          .where((item) => ['text', 'image', 'shareUrl'].contains(item.type))
          .toList();
      if (!data.title.isNullOrEmpty) {
        // data.title 在酷安中可能是"用户名的动态"格式，
        // 顶栏 header 已显示发布者名字，去掉用户名前缀只保留动态标题
        String title = data.title!;
        final uname = data.userInfo?.username ?? data.username;
        if (uname != null && uname.isNotEmpty) {
          // 去掉 "用户名的动态" / "用户名: 动态" 等前缀
          if (title == '$uname的动态' || title == '$uname: 动态') {
            title = ''; // 纯前缀则不显示标题
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
      // 补充 picArr 中的图片：当 articleList 缺少 image 条目时，
      // 用 data.picArr 补全，确保详情页能显示动态中的图片
      if (!data.picArr.isNullOrEmpty) {
        final existing = articleImgList!.toSet();
        for (var img in data.picArr!) {
          if (!existing.contains(img)) {
            articleList!.add(FeedArticle(type: 'image', url: img));
            articleImgList!.add(img);
          }
        }
      }
    } else if (articleList.isNullOrEmpty ||
        data.messageRawOutput == 'null') {
      // 无 messageRawOutput（主页列表预加载数据通常如此）：用 message + picArr
      // 合成 articleList，使详情页预加载即采用 SliverList 布局，与完整数据一致，
      // 避免评论区加载完后从 FeedCard 切换到 SliverList 导致画面跳动
      //
      // 另：当 getFeedData() 返回的完整数据的 messageRawOutput 为 null 或 "null"
      // 字符串时，上面的 if 分支不进入；若预加载阶段已把 articleList 合成为
      // 空数组（如搜索结果返回的精简 Datum 无 message/picArr），原条件
      // articleList == null 为 false 会跳过本分支，导致 articleList 停留空数组，
      // 详情页持续空白。这里把条件改为 articleList.isNullOrEmpty，只要为空就
      // 重新合成，覆盖完整数据返回时 messageRawOutput 为 null 的场景。
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
    if (!data.topReplyRows.isNullOrEmpty) {
      topReply = data.topReplyRows![0];
    } else if (topReply == null && !data.replyRows.isNullOrEmpty) {
      // 主页列表预加载数据无 topReplyRows 时，用 replyRows[0]（列表热评）作为热评，
      // 使评论区在预加载阶段即可显示热评，无需等待评论接口加载完成
      topReply = data.replyRows![0];
    }
    if (!data.replyMeRows.isNullOrEmpty) {
      _replyMe = data.replyMeRows![0];
    }
    feedUsername = data.userInfo?.username;
    feedUid = data.uid;
    feedTypeName = data.feedTypeName;
    replyNum = data.replynum;
  }

  Future<void> getFeedData() async {
    LoadingState<dynamic> response =
        await NetworkRepo.getDataFromUrl(url: '/v6/feed/detail?id=$id');
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
    // 预加载：如果有预传递的数据，立即显示避免转圈，然后后台获取最新数据+评论。
    // 预加载数据若无 messageRawOutput，用 message+picArr 合成 articleList，
    // 保证与 getFeedData() 返回后布局一致（均用 SliverList），避免画面跳动。
    // topReply 在预加载阶段从 replyRows[0] 兜底设置，评论加载后由 handleResponse
    // 前置到评论区列表，使热评显示在评论区而非正文区。
    if (preloadedData != null) {
      _processFeedData(preloadedData!);
      feedState.value = LoadingState.success(preloadedData!);
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
