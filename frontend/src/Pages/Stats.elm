module Pages.Stats exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (MediaStatsResponse, StatsResponse)
import Api.Request.Default exposing (snippetsStatsGet)
import Auth
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
import TypedSvg
import TypedSvg.Attributes
import TypedSvg.Attributes.InEm
import TypedSvg.Attributes.InPx
import TypedSvg.Core
import TypedSvg.Types
import UI.ColorPalette exposing (colorFromScale)
import UI.Dimensions exposing (bodyHeight, bodyWidth)
import UI.Layout as Layout exposing (scaled)
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
        width : Float
        width =
            bodyWidth shared.window

        radius : Float
        radius =
            width / 8.0

        pieData : List Shape.Arc
        pieData =
            media
                |> List.map (\v -> toFloat v.count)
                |> Shape.pie
                    { defaultPieConfig
                        | innerRadius = radius - radius * 0.1
                        , outerRadius = radius
                        , padAngle = 0.02
                        , cornerRadius = 8
                        , sortingFn = \_ _ -> EQ
                    }

        makeSlice : Int -> Shape.Arc -> TypedSvg.Core.Svg msg
        makeSlice index datum =
            Path.element (Shape.arc datum)
                [ TypedSvg.Attributes.fill (TypedSvg.Types.Paint (colorFromScale (toFloat (index + 1) * 120.0)))
                ]

        makeLabel : Shape.Arc -> MediaStatsResponse -> TypedSvg.Core.Svg msg
        makeLabel slice response =
            let
                ( x, y ) =
                    Shape.centroid { slice | innerRadius = radius + 10.0, outerRadius = radius + 10.0 }

                textAnchor : TypedSvg.Types.AnchorAlignment
                textAnchor =
                    if x < 0 then
                        TypedSvg.Types.AnchorEnd

                    else
                        TypedSvg.Types.AnchorStart
            in
            TypedSvg.text_
                [ TypedSvg.Attributes.transform [ TypedSvg.Types.Translate x y ]
                , TypedSvg.Attributes.InEm.dy 0.35
                , TypedSvg.Attributes.textAnchor textAnchor
                , TypedSvg.Attributes.InPx.fontSize (toFloat (scaled -1))
                ]
                [ TypedSvg.Core.text (stringFromMedia shared.translations response.media ++ " (" ++ String.fromInt response.count ++ ")") ]
    in
    Element.html
        (TypedSvg.svg [ TypedSvg.Attributes.InPx.width width, TypedSvg.Attributes.InPx.height (bodyHeight shared.window) ]
            [ TypedSvg.g [ TypedSvg.Attributes.transform [ TypedSvg.Types.Translate (radius + 80) (radius + 40) ] ]
                [ TypedSvg.g [] (List.indexedMap makeSlice pieData)
                , TypedSvg.g [] (List.map2 makeLabel pieData media)
                ]
            ]
        )


loadStats : Auth.User -> ( Model, Cmd Msg )
loadStats session =
    ( { state = Loading }, Api.send StatsLoaded (snippetsStatsGet session.token) )
