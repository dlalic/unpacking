module UI.Dropdown exposing (Dropdown, dropdown, initModel, updateModel)

import Element exposing (Element, column, fill, row, spacing, text, width)
import Element.Font as Font
import Element.Input exposing (labelAbove)
import SearchBox exposing (ChangeEvent)
import UI.ColorPalette exposing (red)
import UI.Dimensions exposing (scaled)


type alias Dropdown =
    { text : String
    , searchBox : SearchBox.State
    }


initModel : Dropdown
initModel =
    { text = "", searchBox = SearchBox.init }


updateModel : ChangeEvent { a | name : String } -> Dropdown -> Dropdown
updateModel changeEvent model =
    case changeEvent of
        SearchBox.SelectionChanged _ ->
            { model | text = "" }

        SearchBox.TextChanged text ->
            { model | text = text, searchBox = SearchBox.reset model.searchBox }

        SearchBox.SearchBoxChanged subMsg ->
            { model | searchBox = SearchBox.update subMsg model.searchBox }


dropdown : String -> Dropdown -> List { a | name : String } -> (ChangeEvent { a | name : String } -> msg) -> List String -> Element msg
dropdown title model list onChange validation =
    column [ width fill, spacing 8 ]
        (row []
            [ SearchBox.input [ width fill ]
                { onChange = onChange
                , text = model.text
                , selected = Nothing
                , options = Just list
                , label = labelAbove [] (text title)
                , placeholder = Nothing
                , toLabel = \m -> m.name
                , filter = \query m -> [ m.name ] |> List.map String.toLower |> List.any (String.contains (String.toLower query))
                , state = model.searchBox
                }
            ]
            :: List.map (\v -> row [ Font.size (scaled -1), Font.color red ] [ text v ]) validation
        )
