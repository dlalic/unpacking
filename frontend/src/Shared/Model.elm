module Shared.Model exposing
    ( Model
    , User
    , Window
    )

import Api.Data exposing (Role)
import I18Next exposing (Translations)
import Uuid exposing (Uuid)


type alias Model =
    { user : Maybe User
    , translations : Translations
    , window : Window
    }


type alias User =
    { token : String
    , id : Uuid
    , role : Role
    }


type alias Window =
    { width : Int, height : Int }
