module Layouts.Layout exposing (Model, Msg, Props, layout)

import Api.Data exposing (Role(..))
import Effect exposing (Effect)
import Element exposing (Element, column, fill, height, padding, row, spacing, width)
import Element.Border as Border
import I18Next exposing (Translations)
import Layout exposing (Layout)
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model exposing (User)
import Translations.Buttons exposing (signOut)
import Translations.Titles exposing (home, name, snippets, sourceCode, stats, terms, users)
import UI.Dimensions exposing (defaultPadding, defaultSpacing, footerHeightInPx)
import UI.Header exposing (HeaderButton, Home, header)
import UI.Link exposing (footerLink)
import UI.TabBar exposing (TabBar, tabBar)
import View exposing (View)


type alias Props =
    { shared : Shared.Model
    }


layout :
    Props
    -> Shared.Model
    -> Route ()
    -> Layout () Model Msg contentMsg
layout props _ route =
    Layout.new
        { init = init
        , update = update
        , view = view props route
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = None


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    ( model, Effect.none )



-- VIEW


view :
    Props
    -> Route ()
    ->
        { toContentMsg : Msg -> contentMsg
        , content : View contentMsg
        , model : Model
        }
    -> View contentMsg
view props route { toContentMsg, model, content } =
    { title = content.title
    , elements =
        List.append (headerAndTabs props.shared route)
            [ column [ width fill, height fill, padding defaultPadding, spacing defaultSpacing ] content.elements
            , footer props.shared.translations
            ]
    }



-- UPDATE


headerAndTabs : Shared.Model -> Route () -> List (Element msg)
headerAndTabs shared route =
    let
        home : Home
        home =
            { title = name shared.translations, route = Route.Path.Home_ }

        button : HeaderButton
        button =
            { title = signOut shared.translations, route = Route.Path.SignOut }
    in
    case shared.user of
        Just user ->
            [ header home (Just button)
            , tabBar shared.window.width (tabs shared route user)
            ]

        Nothing ->
            [ header home Nothing ]


tabs : Shared.Model -> Route () -> User -> List TabBar
tabs shared route user =
    case user.role of
        RoleAdmin ->
            [ { title = home shared.translations, selected = route.path == Route.Path.Home_, route = Route.Path.Home_ }
            , { title = terms shared.translations, selected = route.path == Route.Path.Terms, route = Route.Path.Terms }
            , { title = snippets shared.translations, selected = route.path == Route.Path.Snippets, route = Route.Path.Snippets }
            , { title = stats shared.translations, selected = route.path == Route.Path.Stats, route = Route.Path.Stats }
            , { title = users shared.translations, selected = route.path == Route.Path.Users, route = Route.Path.Users }
            ]

        RoleUser ->
            [ { title = home shared.translations, selected = route.path == Route.Path.Home_, route = Route.Path.Home_ }
            , { title = terms shared.translations, selected = route.path == Route.Path.Terms, route = Route.Path.Terms }
            , { title = snippets shared.translations, selected = route.path == Route.Path.Snippets, route = Route.Path.Snippets }
            , { title = stats shared.translations, selected = route.path == Route.Path.Stats, route = Route.Path.Stats }
            ]


footer : Translations -> Element msg
footer translations =
    row
        [ width fill
        , padding defaultPadding
        , spacing defaultSpacing
        , height footerHeightInPx
        , Border.widthEach { top = 1, bottom = 0, left = 0, right = 0 }
        ]
        [ footerLink (sourceCode translations) "https://github.com/dlalic/unpacking"
        , footerLink "Redaction" "https://www.redaction.us/"
        , footerLink "Public Sans" "https://github.com/uswds/public-sans"
        ]
