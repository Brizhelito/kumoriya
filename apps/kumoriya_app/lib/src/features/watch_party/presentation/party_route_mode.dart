enum PartyRouteMode { standard, party }

extension PartyRouteModeX on PartyRouteMode {
  bool get isParty => this == PartyRouteMode.party;
}
