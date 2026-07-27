import 'package:c001apk_flutter/components/network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/cards/icon_mini_scroll_card.dart' show miniCardItem;
import '../../components/html_text.dart';
import '../../components/icon_text.dart';
import '../../components/imageview.dart';
import '../../components/like_button.dart';
import '../../components/no_splash_factory.dart';
import '../../logic/model/feed/datum.dart';
import '../../utils/app_theme.dart';
import '../../utils/date_util.dart';
import '../../utils/extensions.dart';
import '../../utils/global_data.dart';
import '../../utils/storage_util.dart';
import '../../utils/utils.dart';

class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.data,
    this.isFeedContent = false,
    this.isHistory = false,
    this.showHeader = true,
    this.onDelete,
    this.onBlock,
    this.onLike,
  });

  final Datum data;
  final bool isFeedContent;
  final bool isHistory;
  // 是否显示发帖人 header（动态详情页顶栏已显示时设为 false）
  final bool showHeader;
  final Function(dynamic id)? onDelete;
  final Function(dynamic uid)? onBlock;
  final Function(dynamic id, dynamic like)? onLike;

  void _onViewFeed() {
    // 预加载策略:主页列表的 Datum 有 message + picArr,可合成 articleList,
    // 传 preloadedData 能避免点击后转圈,体验更好。
    // 浏览历史的 Datum 是从 FavHistoryItem 精简转换,字段严重缺失,固定不预加载。
    // 搜索结果等其他场景按 message/picArr 是否存在判断,有任一即预加载。
    // 详情页 _processFeedData 已处理 articleList 为空时用 message+picArr 合成,
    // 且 getFeedData() 返回完整数据后会重新合成,不会停留在空数组。
    final bool shouldPreload = !isHistory &&
        (!data.message.isNullOrEmpty || !data.picArr.isNullOrEmpty);
    debugPrint('[feedDetail] _onViewFeed id=${data.id} '
        'isHistory=$isHistory '
        'shouldPreload=$shouldPreload '
        'message=${data.message == null ? "null" : (data.message!.isEmpty ? "空字符串" : "有值")} '
        'picArr=${data.picArr == null ? "null" : (data.picArr!.isEmpty ? "空数组" : "有${data.picArr!.length}张图")} '
        'messageRawOutput=${data.messageRawOutput == null ? "null" : (data.messageRawOutput == "null" ? '"null"字符串' : "有值")}');
    Get.toNamed('/feed/${data.id}',
        arguments: shouldPreload ? {'datum': data} : null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isFeedContent) {
      // 动态详情页：保持原无卡片样式，仅适配背景
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              header(
                context,
                data,
                isFeedContent,
                isHistory: isHistory,
                onDelete: onDelete,
                onBlock: () {
                  if (onBlock != null) {
                    onBlock!(data.uid);
                  }
                },
              ),
            ..._message(),
            if (!data.picArr.isNullOrEmpty) _image(),
            if (!data.forwardSourceType.isNullOrEmpty)
              _forwardSourceFeed(context),
            if (!data.extraUrl.isNullOrEmpty) _extraUrl(context),
            // 动态详情页不在此处渲染热评（主页列表预载数据的 replyRows），
            // 热评应仅在评论区通过 topReply 显示，避免正文区重复出现
            bottomInfo(context, data, isFeedContent, _onViewFeed, () {
              if (onLike != null) {
                onLike!(data.id, data.userAction?.like);
              }
            }),
            if (data.targetRow != null || !data.relationRows.isNullOrEmpty)
              _rows(context),
          ],
        ),
      );
    }
    // 列表卡片：双主题样式
    // light：半透明白 + 柔和粉绿阴影 + 大圆角
    // dark：深灰底 + 荧光绿细边框 + 软辉光
    final cardRadius = isDark ? 12.0 : 16.0;
    return Material(
      color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        highlightColor: isDark
            ? AppTheme.darkGlow(0.12)
            : AppTheme.lightPrimary.withValues(alpha: 0.06),
        splashColor: isDark
            ? AppTheme.darkGlow(0.08)
            : AppTheme.lightPrimary.withValues(alpha: 0.04),
        splashFactory: isDark ? NoSplashFactory() : null,
        onTap: _onViewFeed,
        onLongPress: () =>
            Get.toNamed('/copy', parameters: {'text': data.message.orEmpty}),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: isDark
                ? Border.all(color: AppTheme.darkCardBorder, width: 1)
                : Border.all(color: AppTheme.lightCardBorder, width: 1),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: AppTheme.darkGlow(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppTheme.lightSecondary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppTheme.lightPrimary.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header(
                context,
                data,
                isFeedContent,
                isHistory: isHistory,
                onDelete: onDelete,
                onBlock: () {
                  if (onBlock != null) {
                    onBlock!(data.uid);
                  }
                },
              ),
              ..._message(),
              if (!data.picArr.isNullOrEmpty) _image(),
              if (!data.forwardSourceType.isNullOrEmpty)
                _forwardSourceFeed(context),
              if (!data.extraUrl.isNullOrEmpty) _extraUrl(context),
              if (!data.replyRows.isNullOrEmpty) _hotReply(context),
              bottomInfo(context, data, isFeedContent, _onViewFeed, () {
                if (onLike != null) {
                  onLike!(data.id, data.userAction?.like);
                }
              }),
              if (data.targetRow != null || !data.relationRows.isNullOrEmpty)
                _rows(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image() {
    return Padding(
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 14,
        top: 10,
        right: isFeedContent ? 16 : 14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxWidth = constraints.maxWidth;
          return image(
            maxWidth,
            data.picArr!,
          );
        },
      ),
    );
  }

  Widget _forwardSourceFeed(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 10,
        top: 10,
        right: isFeedContent ? 16 : 10,
      ),
      child: Material(
        color: isFeedContent
            ? Theme.of(context).colorScheme.onInverseSurface
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: data.forwardSourceFeed != null
              ? () => Get.toNamed('/feed/${data.forwardSourceFeed?.id}')
              : null,
          onLongPress: data.forwardSourceFeed != null
              ? () => Get.toNamed('/copy',
                  parameters: {'text': data.forwardSourceFeed?.message ?? ''})
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: data.forwardSourceFeed == null
                ? Text(
                    '动态已被删除',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!data
                          .forwardSourceFeed!.messageTitle.isNullOrEmpty) ...[
                        htmlText(
                            '<a class="feed-link-uname" href="/u/${data.forwardSourceFeed?.uid}">@${data.forwardSourceFeed?.username}</a>: ${data.forwardSourceFeed?.messageTitle}'),
                        htmlText(data.forwardSourceFeed?.message ?? ''),
                      ],
                      if (data.forwardSourceFeed!.messageTitle.isNullOrEmpty)
                        htmlText(
                            '<a class="feed-link-uname" href="/u/${data.forwardSourceFeed?.uid}">@${data.forwardSourceFeed?.username}</a>: ${data.forwardSourceFeed?.message}'),
                      if (!data.forwardSourceFeed!.picArr.isNullOrEmpty) ...[
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) => image(
                              constraints.maxWidth,
                              data.forwardSourceFeed!.picArr!),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _extraUrl(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 10,
        top: 10,
        right: isFeedContent ? 16 : 10,
      ),
      child: Material(
        color: isFeedContent
            ? Theme.of(context).colorScheme.onInverseSurface
            : Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: () => Utils.onOpenLink(data.extraUrl!, data.extraTitle ?? ''),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                !data.extraPic.isNullOrEmpty
                    ? clipNetworkImage(
                        data.extraPic!,
                        radius: 8,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        child: Icon(
                          Icons.link_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.extraTitle.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data.extraUrl.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hotReply(BuildContext context) {
    var reply = data.replyRows![0];
    var replyPic = reply.picArr.isNullOrEmpty
        ? ''
        : ''' <a class="feed-forward-pic" href=${reply.pic}>查看图片(${reply.picArr!.length})</a>''';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 10, top: 10, right: 10),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: _onViewFeed,
          onLongPress: () =>
              Get.toNamed('/copy', parameters: {'text': reply.message.orEmpty}),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: htmlText(
              """<a class="feed-link-uname" href="/u/${reply.uid}">${reply.userInfo?.username}</a>: ${reply.message}$replyPic""",
              fontSize: 14,
              onShowTotalReply: _onViewFeed,
              picArr: reply.picArr,
            ),
          ),
        ),
      ),
    );
  }

  Widget _rows(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isFeedContent ? 16 : 10,
        top: 10,
        right: isFeedContent ? 16 : 10,
      ),
      child: Wrap(
        spacing: 5.0,
        runSpacing: 5.0,
        children: [
          if (data.targetRow != null)
            miniCardItem(
              context,
              data.targetRow!.logo!.orEmpty,
              data.targetRow!.title.orEmpty,
              data.targetRow!.url.orEmpty,
              isFeedContent ? false : true,
              false,
            ),
          if (!data.relationRows.isNullOrEmpty)
            ...data.relationRows!.map(
              (item) => miniCardItem(
                context,
                item.logo.orEmpty,
                item.title.orEmpty,
                item.url.orEmpty,
                isFeedContent ? false : true,
                false,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _message() {
    return [
      // 动态详情页顶栏已显示发帖人信息，messageTitle（"用户名: 动态"）不再重复
      if (!isFeedContent && !data.messageTitle.isNullOrEmpty)
        Padding(
          padding: EdgeInsets.only(
            left: isFeedContent ? 16 : 14,
            top: 8,
            right: isFeedContent ? 16 : 14,
          ),
          child: htmlText(
            data.messageTitle.orEmpty,
            fontSize: 16,
            isBold: true,
          ),
        ),
      Padding(
        padding: EdgeInsets.only(
          left: isFeedContent ? 16 : 14,
          top: 6,
          right: isFeedContent ? 16 : 14,
        ),
        child: htmlText(
          data.message.orEmpty,
          fontSize: 16,
          onClick: _onViewFeed,
        ),
      )
    ];
  }
}

Widget header(
  BuildContext context,
  Datum data,
  bool isFeedContent, {
  bool isHeader = false,
  bool isHistory = false,
  Function(dynamic id)? onDelete,
  Function()? onBlock,
}) {
  return Row(
    children: [
      Flexible(
        flex: 1,
        child: Padding(
          padding: EdgeInsets.only(
            left: isHeader
                ? 0
                : isFeedContent
                    ? 16
                    : 10,
            top: isHeader
                ? 0
                : isFeedContent
                    ? 12
                    : 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Get.toNamed('/u/${data.uid}'),
                child: clipNetworkImage(
                  data.userAvatar.orEmpty,
                  radius: 50,
                  width: 35,
                  height: 35,
                  isAvatar: true,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.userInfo?.username ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isFeedContent || !data.infoHtml.isNullOrEmpty) ...[
                          Text(
                            isFeedContent
                                ? DateUtil.fromToday(data.dateline)
                                : Utils.parseHtmlString(data.infoHtml.orEmpty),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (!data.deviceTitle.isNullOrEmpty)
                          Flexible(
                            flex: 1,
                            child: IconText(
                              icon: Icons.smartphone,
                              text: Utils.parseHtmlString(
                                  data.deviceTitle.orEmpty),
                            ),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (!isFeedContent && data.isStickTop == 1)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            border: Border.all(
              width: 1.25,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: Text(
            '置顶',
            style: TextStyle(
              height: 1,
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
            strutStyle: const StrutStyle(
              leading: 0,
              height: 1,
              fontSize: 12,
            ),
          ),
        ),
      if (!isFeedContent)
        IconButton(
          onPressed: () => showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            builder: (context) {
              return _MorePanel(
                id: data.id,
                uid: data.uid,
                isHistory: isHistory,
                onDelete: onDelete,
                onBlock: onBlock,
              );
            },
          ),
          icon: const Icon(Icons.keyboard_arrow_down),
          color: Theme.of(context).colorScheme.outline,
        ),
    ],
  );
}

Widget bottomInfo(
  BuildContext context,
  Datum data,
  bool isFeedContent,
  Function()? onViewFeed,
  Function()? onLike, {
  bool isFeedArticle = false,
}) {
  return Padding(
    padding: EdgeInsets.only(
      left: isFeedContent ? 16 : 10,
      top: isFeedArticle ? 0 : 10,
      right: isFeedContent ? 16 : 10,
    ),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            isFeedContent
                ? !data.ipLocation.isNullOrEmpty
                    ? '发布于 ${data.ipLocation}'
                    : ''
                : DateUtil.fromToday(data.dateline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ),
        if (data.replynum != null)
          LikeButton(
            value: data.replynum,
            icon: Icons.message_outlined,
            // onClick: () {
            //   // todo
            //   SmartDialog.showToast('${data.replynum}');
            // },
          ),
        if (data.likenum != null)
          LikeButton(
            value: data.likenum,
            icon: data.userAction?.like == 1
                ? Icons.thumb_up
                : Icons.thumb_up_alt_outlined,
            isLike: data.userAction?.like == 1,
            onClick: () {
              if (GlobalData().isLogin && onLike != null) {
                onLike();
              }
            },
          ),
      ],
    ),
  );
}

enum PanelAction { copy, block, report, delete }

class _MorePanel extends StatelessWidget {
  const _MorePanel({
    required this.id,
    required this.uid,
    required this.isHistory,
    required this.onDelete,
    required this.onBlock,
  });

  final dynamic id;
  final dynamic uid;
  final bool isHistory;
  final Function(dynamic id)? onDelete;
  final Function()? onBlock;

  Future<dynamic> menuActionHandler(PanelAction type) async {
    switch (type) {
      case PanelAction.copy:
        Utils.copyText('https://www.coolapk.com/feed/$id');
        Get.back();
        break;
      case PanelAction.block:
        Get.back();
        GStorage.onBlock(uid);
        if (onBlock != null) {
          onBlock!();
        }
        break;
      case PanelAction.report:
        Get.back();
        Utils.report(id, ReportType.Feed);
        break;
      case PanelAction.delete:
        Get.back();
        if (onDelete != null) {
          onDelete!(id);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            onTap: () => Get.back(),
            child: Container(
              alignment: Alignment.center,
              height: 35,
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            onTap: () async => await menuActionHandler(PanelAction.copy),
            minLeadingWidth: 0,
            leading: const Icon(Icons.copy_outlined, size: 19),
            title: Text('Copy', style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            onTap: () async => await menuActionHandler(PanelAction.block),
            minLeadingWidth: 0,
            leading: const Icon(Icons.block, size: 19),
            title: Text('Block', style: Theme.of(context).textTheme.titleSmall),
          ),
          if (Utils.isSupportWebview())
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.report),
              minLeadingWidth: 0,
              leading: const Icon(Icons.error_outline, size: 19),
              title:
                  Text('Report', style: Theme.of(context).textTheme.titleSmall),
            ),
          if (isHistory || uid.toString() == GlobalData().uid)
            ListTile(
              onTap: () async => await menuActionHandler(PanelAction.delete),
              minLeadingWidth: 0,
              leading: const Icon(Icons.delete_outline, size: 19),
              title:
                  Text('Delete', style: Theme.of(context).textTheme.titleSmall),
            ),
        ],
      ),
    );
  }
}
