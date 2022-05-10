# BoxRP.UDataFacade
Higher-level facade for `BoxRP.UData`

-- By calling `.Register(objname)` type `BoxRP.UDataFacade.Facade($objname)` is registered

`fn .Register(objname: string) -> .FacadeFactory`

`readonly var .List: table(objname: string, .FacadeFactory)`

`type .FacadeFactory`

`type .Facade`

`inferred_type TFacade: .Facade <individual to each instance of .FacadeFactory>`

`var .FacadeFactory.Metatable: metatable(TFacade)`

`var .FacadeFactory.ObjectType: string`

`fn .FacadeFactory:Load(id: BoxRP.UData.ObjectId) -> TFacade|nil, error_msg: nil|string`

`fn .FacadeFactory:Create(vars: table(string, TVariable)) -> TFacade|nil, error_msg: nil|string`

`readonly var .FacadeFactory.Instances: table(BoxRP.UData.ObjectId, TFacade)`

`fn .Facade:Unload()`

`fn .Facade:Delete()`

`var .Facade.Data: BoxRP.UData.Object`

`fn .Facade:IsValid() -> bool`