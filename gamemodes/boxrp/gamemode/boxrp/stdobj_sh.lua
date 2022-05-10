BoxRP.StdObj = {}

BoxRP.UData.RegisterObject("core.char")
BoxRP.StdObj.CharFact = BoxRP.UDataFacade.Register("core.char")
BoxRP.StdObj.Char = BoxRP.StdObj.CharFact.Meta

BoxRP.UData.RegisterObject("core.item")
BoxRP.StdObj.ItemFact = BoxRP.UDataFacade.Register("core.item")
BoxRP.StdObj.Item = BoxRP.StdObj.ItemFact.Meta

BoxRP.UData.RegisterObject("core.inv")
BoxRP.StdObj.InvFact = BoxRP.UDataFacade.Register("core.inv")
BoxRP.StdObj.Inv = BoxRP.StdObj.InvFact.Meta