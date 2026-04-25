import 'package:flutter/foundation.dart';

@immutable
class SidebarOrder {
  const SidebarOrder({
    this.channelOrder = const [],
    this.dmOrder = const [],
    this.pinnedChannelIds = const [],
    this.pinnedOrder = const [],
    this.hiddenDmIds = const [],
    this.agentOrder = const [],
    this.pinnedAgentIds = const [],
  });

  final List<String> channelOrder;
  final List<String> dmOrder;
  final List<String> pinnedChannelIds;
  final List<String> pinnedOrder;
  final List<String> hiddenDmIds;
  final List<String> agentOrder;
  final List<String> pinnedAgentIds;

  bool isChannelPinned(String channelId) =>
      pinnedChannelIds.contains(channelId);

  bool isDmHidden(String dmId) => hiddenDmIds.contains(dmId);

  bool isAgentPinned(String agentId) => pinnedAgentIds.contains(agentId);

  SidebarOrder copyWith({
    List<String>? channelOrder,
    List<String>? dmOrder,
    List<String>? pinnedChannelIds,
    List<String>? pinnedOrder,
    List<String>? hiddenDmIds,
    List<String>? agentOrder,
    List<String>? pinnedAgentIds,
  }) {
    return SidebarOrder(
      channelOrder: channelOrder ?? this.channelOrder,
      dmOrder: dmOrder ?? this.dmOrder,
      pinnedChannelIds: pinnedChannelIds ?? this.pinnedChannelIds,
      pinnedOrder: pinnedOrder ?? this.pinnedOrder,
      hiddenDmIds: hiddenDmIds ?? this.hiddenDmIds,
      agentOrder: agentOrder ?? this.agentOrder,
      pinnedAgentIds: pinnedAgentIds ?? this.pinnedAgentIds,
    );
  }

  Map<String, Object> toPatchMap({
    bool includeChannelOrder = false,
    bool includeDmOrder = false,
    bool includePinnedChannelIds = false,
    bool includePinnedOrder = false,
    bool includeHiddenDmIds = false,
    bool includeAgentOrder = false,
    bool includePinnedAgentIds = false,
  }) {
    return {
      if (includeChannelOrder) 'channelOrder': channelOrder,
      if (includeDmOrder) 'dmOrder': dmOrder,
      if (includePinnedChannelIds) 'pinnedChannelIds': pinnedChannelIds,
      if (includePinnedOrder) 'pinnedOrder': pinnedOrder,
      if (includeHiddenDmIds) 'hiddenDmIds': hiddenDmIds,
      if (includeAgentOrder) 'agentOrder': agentOrder,
      if (includePinnedAgentIds) 'pinnedAgentIds': pinnedAgentIds,
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
            listEquals(hiddenDmIds, other.hiddenDmIds) &&
            listEquals(agentOrder, other.agentOrder) &&
            listEquals(pinnedAgentIds, other.pinnedAgentIds);
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(channelOrder),
        Object.hashAll(dmOrder),
        Object.hashAll(pinnedChannelIds),
        Object.hashAll(pinnedOrder),
        Object.hashAll(hiddenDmIds),
        Object.hashAll(agentOrder),
        Object.hashAll(pinnedAgentIds),
      );
}
