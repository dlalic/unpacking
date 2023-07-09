module Pages.SignOut exposing (Model, Msg, page)

import Element exposing (Element, text)
import Gen.Params.SignOut exposing (Params)
import Gen.Route as Route
import Page
import Request exposing (Request)
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (signIn, signOut)
import Translations.Labels exposing (onSignOut)
import UI.Button exposing (defaultButton)
import UI.Layout as Layout
import View exposing (View)


page : Shared.Model -> Request.With Params -> Page.With Model Msg
page shared req =
    Page.element
        { init = init shared.storage
        , update = update req
        , view = view shared
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    {}


init : Storage -> ( Model, Cmd Msg )
init storage =
    ( {}, Storage.signOut storage )


type Msg
    = ClickedSignIn


update : Request -> Msg -> Model -> ( Model, Cmd Msg )
update req msg model =
    case msg of
        ClickedSignIn ->
            ( model, Request.pushRoute Route.SignIn req )


view : Shared.Model -> Model -> View Msg
view shared _ =
    { title = signOut shared.translations
    , body = Layout.layout Route.SignOut shared (viewSignOut shared)
    }


viewSignOut : Shared.Model -> List (Element Msg)
viewSignOut shared =
    [ text (onSignOut shared.translations)
    , defaultButton (signIn shared.translations) ClickedSignIn
    ]
