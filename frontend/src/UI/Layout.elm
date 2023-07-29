module UI.Layout exposing (layout, scaled)

import Api.Data exposing (Role(..))
import Domain.Session exposing (Session)
import Element exposing (Element, centerX, column, fill, height, padding, row, spacing, width)
import Element.Border as Border
import Element.Font as Font
import Gen.Route as Route exposing (Route)
import Html exposing (Html)
import I18Next exposing (Translations)
import Shared
import Translations.Buttons exposing (signOut)
import Translations.Titles exposing (home, name, snippets, sourceCode, stats, terms, users)
import UI.Dimensions exposing (fillMaxViewWidth)
import UI.Header exposing (HeaderButton, Home, header)
import UI.Link exposing (footerLink)
import UI.TabBar exposing (TabBar, tabBar)


layout : Route -> Shared.Model -> List (Element msg) -> List (Html msg)
layout route shared children =
    [ Element.layout
        [ Font.family [ Font.typeface "Public Sans", Font.sansSerif ]
        ]
        (column [ fillMaxViewWidth, height fill, centerX ]
            (List.append (headerAndTabs shared route)
                [ column [ width fill, height fill, padding 20, spacing 20 ] children
                , footer shared.translations
                ]
            )
        )
    ]


scaled : Int -> Int
scaled n =
    ceiling (Element.modular 16 1.25 n)


headerAndTabs : Shared.Model -> Route -> List (Element msg)
headerAndTabs shared route =
    let
        home : Home
        home =
            { title = name shared.translations, route = Route.Home_ }

        button : HeaderButton
        button =
            { title = signOut shared.translations, route = Route.SignOut }
    in
    case shared.storage.session of
        Just session ->
            [ header home (Just button)
            , tabBar shared.window.width (tabs shared route session)
            ]

        Nothing ->
            [ header home Nothing ]


tabs : Shared.Model -> Route -> Session -> List TabBar
tabs shared route session =
    case session.role of
        RoleAdmin ->
            [ { title = home shared.translations, selected = route == Route.Home_, route = Route.Home_ }
            , { title = terms shared.translations, selected = route == Route.Terms, route = Route.Terms }
            , { title = snippets shared.translations, selected = route == Route.Snippets, route = Route.Snippets }
            , { title = stats shared.translations, selected = route == Route.Stats, route = Route.Stats }
            , { title = users shared.translations, selected = route == Route.Users, route = Route.Users }
            ]

        RoleUser ->
            [ { title = home shared.translations, selected = route == Route.Home_, route = Route.Home_ }
            , { title = terms shared.translations, selected = route == Route.Terms, route = Route.Terms }
            , { title = snippets shared.translations, selected = route == Route.Snippets, route = Route.Snippets }
            , { title = stats shared.translations, selected = route == Route.Stats, route = Route.Stats }
            ]


footer : Translations -> Element msg
footer translations =
    row
        [ width fill
        , padding 20
        , spacing 20
        , Border.widthEach { top = 1, bottom = 0, left = 0, right = 0 }
        ]
        [ footerLink (sourceCode translations) "https://github.com/dlalic/unpacking"
        , footerLink "Redaction" "https://www.redaction.us/"
        , footerLink "Public Sans" "https://github.com/uswds/public-sans"
        ]
