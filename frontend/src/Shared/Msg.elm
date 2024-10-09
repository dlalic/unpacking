module Shared.Msg exposing (Msg(..))

import Api.Data exposing (Role)
import Http
import I18Next exposing (Translations)
import Uuid exposing (Uuid)


{-| Normally, this value would live in "Shared.elm"
but that would lead to a circular dependency import cycle.

For that reason, both `Shared.Model` and `Shared.Msg` are in their
own file, so they can be imported by `Effect.elm`

-}
type Msg
    = SignIn { token : String, id : Uuid, role : Role }
    | SignOut
    | LoadedTranslations (Result Http.Error Translations)
    | SetScreenSize Int Int
