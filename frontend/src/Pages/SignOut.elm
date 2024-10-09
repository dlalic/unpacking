module Pages.SignOut exposing (Model, Msg, page)

import Auth
import Dict
import Effect exposing (Effect)
import Element exposing (Element, text)
import Layouts
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import Translations.Buttons exposing (signIn, signOut)
import Translations.Labels exposing (onSignOut)
import UI.Button exposing (defaultButton)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page _ shared route =
    Page.new
        { init = init
        , update = update route
        , subscriptions = \_ -> Sub.none
        , view = view shared
        }
        |> Page.withLayout (layout shared)


layout : Shared.Model -> Model -> Layouts.Layout Msg
layout shared _ =
    Layouts.Layout { shared = shared }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}, Effect.signOut )



-- UPDATE


type Msg
    = ClickedSignIn


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case msg of
        ClickedSignIn ->
            ( model
            , Effect.pushRoute
                { path =
                    Dict.get "from" route.query
                        |> Maybe.andThen Route.Path.fromString
                        |> Maybe.withDefault Route.Path.Home_
                , query = Dict.empty
                , hash = Nothing
                }
            )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared _ =
    { title = signOut shared.translations
    , elements = viewSignOut shared
    }


viewSignOut : Shared.Model -> List (Element Msg)
viewSignOut shared =
    [ text (onSignOut shared.translations)
    , defaultButton (signIn shared.translations) ClickedSignIn
    ]



-- SUBSCRIPTIONS
