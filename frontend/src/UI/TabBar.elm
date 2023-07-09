module UI.TabBar exposing (TabBar, tabBar)

import Element exposing (Attribute, Element, column, fill, htmlAttribute, link, mouseOver, moveUp, padding, row, spacing, text, width)
import Element.Border as Border
import Element.Font as Font
import Gen.Route as Route exposing (Route)
import Simple.Transition as Transition
import UI.Dimensions exposing (smallScreenWidth)


type alias TabBar =
    { title : String
    , selected : Bool
    , route : Route
    }


tabBar : Int -> List TabBar -> Element msg
tabBar windowWidth models =
    if windowWidth < smallScreenWidth then
        column [ width fill, padding 20, spacing 20, Border.widthEach { left = 0, top = 0, right = 0, bottom = 1 } ] (List.map tabBarButton models)

    else
        row [ width fill, padding 20, spacing 20, Border.widthEach { left = 0, top = 0, right = 0, bottom = 1 } ] (List.map tabBarButton models)


tabBarButton : TabBar -> Element msg
tabBarButton model =
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
        , Font.size 18
        , properties_
            [ Transition.transform 500 [ Transition.delay 200 ]
            ]
        , mouseOver
            [ moveUp 2
            ]
        ]
        { url = Route.toHref model.route
        , label = text model.title
        }


properties_ : List Transition.Property -> Attribute msg
properties_ =
    htmlAttribute << Transition.properties
