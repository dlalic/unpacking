module UI.TabBar exposing (TabBar, tabBar)

import Element exposing (Attribute, Element, column, fill, height, htmlAttribute, link, mouseOver, moveUp, padding, row, spacing, text, width)
import Element.Border as Border
import Element.Font as Font
import Route.Path
import Simple.Transition as Transition
import UI.Dimensions exposing (defaultPadding, defaultSpacing, headerHeightInPx, smallScreenWidth)


type alias TabBar =
    { title : String
    , selected : Bool
    , route : Route.Path.Path
    }


tabBar : Int -> List TabBar -> Element msg
tabBar windowWidth models =
    let
        style : List (Attribute msg)
        style =
            [ width fill
            , padding defaultPadding
            , spacing defaultSpacing
            , Border.widthEach { left = 0, top = 0, right = 0, bottom = 1 }
            ]
    in
    if windowWidth < smallScreenWidth then
        column style (List.map (tabBarButton 16) models)

    else
        row (height headerHeightInPx :: style) (List.map (tabBarButton 18) models)


tabBarButton : Int -> TabBar -> Element msg
tabBarButton size model =
    let
        font : Attribute msg
        font =
            if model.selected then
                Font.bold

            else
                Font.regular
    in
    link
        [ font
        , Font.size size
        , properties_
            [ Transition.transform 500 [ Transition.delay 200 ]
            ]
        , mouseOver
            [ moveUp 2
            ]
        ]
        { url = Route.Path.toString model.route
        , label = text model.title
        }


properties_ : List Transition.Property -> Attribute msg
properties_ =
    htmlAttribute << Transition.properties
