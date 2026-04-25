import 'package:flutter/foundation.dart';

@immutable
class SidebarOrder {
  const SidebarOrder({
    this.channelOrder = const [],
    this.dmOrder = const [],
    this.pinnedChannelIds = const [],
    this.pinnedOrder = const [],
    this.hiddenDmIds = const [],
  });

  final List<String> channelOrder;
  final List<String> dmOrder;
  final List<String> pinnedChannelIds;
  final List<String> pinnedOrder;
  final List<String> hiddenDmIds;

  bool isChannelPinned(String channelId) =>
      pinnedChannelIds.contains(channelId);

  bool isDmHidden(String dmId) => hiddenDmIds.contains(dmId);

  SidebarOrder copyWith({
    List<String>? channelOrder,
    List<String>? dmOrder,
    List<String>? pinnedChannelIds,
    List<String>? pinnedOrder,
    List<String>? hiddenDmIds,
  }) {
    return SidebarOrder(
      channelOrder: channelOrder ?? this.channelOrder,
      dmOrder: dmOrder ?? this.dmOrder,
      pinnedChannelIds: pinnedChannelIds ?? this.pinnedChannelIds,
      pinnedOrder: pinnedOrder ?? this.pinnedOrder,
      hiddenDmIds: hiddenDmIds ?? this.hiddenDmIds,
    );
  }

  Map<String, Object> toPatchMap({
    bool includeChannelOrder = false,
    bool includeDmOrder = false,
    bool includePinnedChannelIds = false,
    bool includePinnedOrder = false,
    bool includeHiddenDmIds = false,
  }) {
    return {
      if (includeChannelOrder) 'channelOrder': channelOrder,
      if (includeDmOrder) 'dmOrder': dmOrder,
      if (includePinnedChannelIds) 'pinnedChannelIds': pinnedChannelIds,
      if (includePinnedOrder) 'pinnedOrder': pinnedOrder,
      if (includeHiddenDmIds) 'hiddenDmIds': hiddenDmIds,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SidebarOrder &&
            runtimeType == other.runtimeType &&
            listEquals(channelOrder, other.channelOrder) &&
            listEquals(dmOrder, other.dmOrder) &&
            listEquals(pinnedChannelIds, other.pinnedChannelIds) &&
            listEquals(pinnedOrder, other.pinnedOrder) &&
            listEquals(hiddenDmIds, other.hiddenDmIds);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(channelOrder),
        Object.hashAll(dmOrder),
        Object.hashAll(pinnedChannelIds),
        Object.hashAll(pinnedOrder),
        Object.hashAll(hiddenDmIds),
      );
}
