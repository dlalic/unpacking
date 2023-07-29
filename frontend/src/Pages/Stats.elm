module Pages.Stats exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (MediaStatsResponse, StatsResponse)
import Api.Request.Default exposing (snippetsStatsGet)
import Auth
import Color
import Element exposing (Element, text)
import Forms.SnippetForm exposing (stringFromMedia)
import Gen.Route as Route
import Http
import Page
import Path
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import Shape exposing (defaultPieConfig)
import Shared
import Storage exposing (Storage)
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (stats)
import TypedSvg exposing (g, svg, text_)
import TypedSvg.Attributes exposing (stroke, textAnchor, transform)
import TypedSvg.Attributes.InPx exposing (height, width)
import TypedSvg.Core exposing (Svg)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..))
import UI.ColorPalette exposing (colorFromScale)
import UI.Layout as Layout
import View exposing (View)


page : Shared.Model -> Request -> Page.With Model Msg
page shared _ =
    Page.protected.element
        (\session ->
            { init = init session
            , update = update shared.storage
            , view = view shared
            , subscriptions = \_ -> Sub.none
            }
        )


type alias Model =
    { state : State
    }


type State
    = Loading
    | Loaded StatsResponse
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    loadStats session


type Msg
    = StatsLoaded (Result Http.Error StatsResponse)


update : Storage -> Msg -> Model -> ( Model, Cmd Msg )
update storage msg model =
    case msg of
        StatsLoaded (Ok response) ->
            ( { model | state = Loaded response }, Cmd.none )

        StatsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = stats shared.translations
    , body = Layout.layout Route.Stats shared (viewStats shared model)
    }


viewStats : Shared.Model -> Model -> List (Element Msg)
viewStats shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded response ->
            [ pieChart shared response.media ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


pieChart : Shared.Model -> List MediaStatsResponse -> Element msg
pieChart shared media =
    let
        radius : Float
        radius =
            toFloat (min shared.window.width 1024 // 2)

        pieData : List Shape.Arc
        pieData =
            media
                |> List.map (\v -> toFloat v.count)
                |> Shape.pie
                    { defaultPieConfig
                        | innerRadius = radius / 3.0
                        , outerRadius = radius / 3.0 + 20.0
                        , padAngle = 0.02
                        , cornerRadius = 8
                        , sortingFn = \_ _ -> EQ
                    }

        makeSlice : Int -> Shape.Arc -> Svg msg
        makeSlice index datum =
            Path.element (Shape.arc datum) [ TypedSvg.Attributes.fill (Paint (colorFromScale (toFloat (index + 1) * 120.0))), stroke (Paint Color.white) ]

        makeLabel : Shape.Arc -> MediaStatsResponse -> Svg msg
        makeLabel slice response =
            let
                ( x, y ) =
                    Shape.centroid { slice | innerRadius = radius / 3.0 + 60.0, outerRadius = radius / 3.0 + 80.0 }
            in
            text_
                [ transform [ Translate x y ]
                , textAnchor AnchorMiddle
                ]
                [ TypedSvg.Core.text (stringFromMedia shared.translations response.media ++ "(" ++ String.fromInt response.count ++ ")") ]
    in
    Element.html
        (svg [ width (radius * 2), height (radius * 2) ]
            [ g [ transform [ Translate radius radius ] ]
                [ g [] (List.indexedMap makeSlice pieData)
                , g [] (List.map2 makeLabel pieData media)
                ]
            ]
        )


loadStats : Auth.User -> ( Model, Cmd Msg )
loadStats session =
    ( { state = Loading }, Api.send StatsLoaded (snippetsStatsGet session.token) )
