module Pages.Stats exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (MediaStatsResponse, StatsResponse)
import Api.Request.Default exposing (snippetsStatsGet)
import Auth
import Effect exposing (Effect)
import Element exposing (Element, text)
import Forms.SnippetForm exposing (stringFromMedia)
import Http
import Layouts
import Page exposing (Page)
import Path
import Problem exposing (isUnauthenticated)
import Route exposing (Route)
import Shape exposing (defaultPieConfig)
import Shared
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (stats)
import TypedSvg
import TypedSvg.Attributes
import TypedSvg.Attributes.InEm
import TypedSvg.Attributes.InPx
import TypedSvg.Core
import TypedSvg.Types
import UI.ColorPalette exposing (colorFromScale)
import UI.Dimensions exposing (bodyHeight, bodyWidth, scaled)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view shared
        }
        |> Page.withLayout (layout shared)


layout : Shared.Model -> Model -> Layouts.Layout Msg
layout shared _ =
    Layouts.Layout { shared = shared }



-- INIT


type alias Model =
    { state : State
    }


type State
    = Loading
    | Loaded StatsResponse
    | Errored String


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    loadStats user



-- UPDATE


type Msg
    = StatsLoaded (Result Http.Error StatsResponse)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        StatsLoaded (Ok response) ->
            ( { model | state = Loaded response }, Effect.none )

        StatsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = stats shared.translations
    , elements = viewStats shared model
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


loadStats : Auth.User -> ( Model, Effect Msg )
loadStats session =
    ( { state = Loading }, Effect.sendCmd (Api.send StatsLoaded (snippetsStatsGet session.token)) )



-- SUBSCRIPTIONS
