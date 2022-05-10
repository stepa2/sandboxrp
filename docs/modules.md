# Standard modules documentation

## core_char_owner
Optionaly associates some entity to character as owner.
I.e. player that uses that character now, non-player-character entity, no owner when character has no entity representation.

If owner is a player, he is added to receiver list.

`fn BoxRP.StdObj.Char:CoreGetOwner() -> Entity|nil`
`fn BoxRP.StdObj.Char:CoreSetOwner(owner: Entity|nil)`