module Pages.Home_ exposing (GraphState, Model, Msg, State, page)

import Api
import Api.Data exposing (TermGraphResponse)
import Api.Request.Default exposing (termsGraphGet)
import Auth
import Browser.Dom as Dom
import Browser.Events as Events
import Color
import Element exposing (Element, text)
import Force
import Gen.Route as Route
import Graph exposing (Edge, Graph, Node, NodeContext, NodeId)
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import Shared
import Storage exposing (Storage)
import Task
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (home)
import TypedSvg
import TypedSvg.Attributes
import TypedSvg.Attributes.InPx
import TypedSvg.Core
import TypedSvg.Types
import UI.ColorPalette exposing (colorFromScale)
import UI.Dimensions exposing (bodyHeight, bodyWidth)
import UI.Layout as Layout
import View exposing (View)
import Zoom exposing (OnZoom, Zoom)


page : Shared.Model -> Request -> Page.With Model Msg
page shared _ =
    Page.protected.element
        (\session ->
            { init = init session
            , update = update shared.storage
            , view = view shared
            , subscriptions = subscriptions
            }
        )


type alias Model =
    { session : Auth.User
    , state : State
    , graphState : GraphState
    , selected : Maybe String
    }


type GraphState
    = Init (Graph Entity ())
    | Ready ReadyState


type alias ReadyState =
    { graph : Graph Entity ()
    , simulation : Force.State NodeId
    , zoom : Zoom
    , element : SVGElement
    , showGraph : Bool
    }


type alias SVGElement =
    { height : Float
    , width : Float
    , x : Float
    , y : Float
    }


type alias Entity =
    Force.Entity NodeId { value : String }


type State
    = Loading
    | Loaded
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    loadTerms session


type Msg
    = TermsLoaded (Result Http.Error TermGraphResponse)
    | ReceiveElementPosition (Result Dom.Error Dom.Element)
    | Resize
    | Tick
    | ZoomMsg OnZoom


update : Storage -> Msg -> Model -> ( Model, Cmd Msg )
update storage msg model =
    let
        initNode : NodeContext String () -> NodeContext Entity ()
        initNode ctx =
            { node =
                { label = Force.entity ctx.node.id ctx.node.label
                , id = ctx.node.id
                }
            , incoming = ctx.incoming
            , outgoing = ctx.outgoing
            }

        initSimulation : Graph Entity () -> Float -> Float -> Force.State NodeId
        initSimulation graph width height =
            let
                link : { c | from : a, to : b } -> ( a, b )
                link { from, to } =
                    ( from, to )
            in
            Force.simulation
                [ Force.links (List.map link (Graph.edges graph))
                , Force.manyBodyStrength -150 (List.map .id (Graph.nodes graph))
                , Force.collision 40 (List.map .id (Graph.nodes graph))
                , Force.center (width / 2) (height / 2)
                ]
                |> Force.iterations 60

        initZoom : SVGElement -> Zoom
        initZoom element =
            Zoom.init { width = element.width, height = element.height }
                |> Zoom.scaleExtent 0.1 2

        handleTick : ReadyState -> ( Model, Cmd Msg )
        handleTick state =
            let
                ( newSimulation, list ) =
                    Force.tick state.simulation (List.map .label (Graph.nodes state.graph))
            in
            ( { model
                | graphState =
                    Ready
                        { state
                            | graph = updateGraphWithList state.graph list
                            , showGraph = True
                            , simulation = newSimulation
                        }
              }
            , Cmd.none
            )

        updateContextWithValue : NodeContext Entity () -> Entity -> NodeContext Entity ()
        updateContextWithValue nodeCtx value =
            let
                node : Node Entity
                node =
                    nodeCtx.node
            in
            { nodeCtx | node = { node | label = value } }

        updateGraphWithList : Graph Entity () -> List Entity -> Graph Entity ()
        updateGraphWithList =
            let
                graphUpdater : Entity -> Maybe (NodeContext Entity ()) -> Maybe (NodeContext Entity ())
                graphUpdater value =
                    Maybe.map (\ctx -> updateContextWithValue ctx value)
            in
            List.foldr (\node graph -> Graph.update node.id (graphUpdater node) graph)
    in
    case msg of
        TermsLoaded (Ok response) ->
            let
                graph : Graph String ()
                graph =
                    Graph.fromNodeLabelsAndEdgePairs response.terms (List.map tuple response.nodes)

                tuple : List Int -> ( Int, Int )
                tuple input =
                    case input of
                        [ a, b ] ->
                            ( a, b )

                        _ ->
                            ( 0, 0 )
            in
            ( { model | state = Loaded, graphState = Init (Graph.mapContexts initNode graph) }, getElementPosition )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ReceiveElementPosition (Ok { element }) ->
            case model.graphState of
                Ready state ->
                    ( { model
                        | graphState =
                            Ready
                                { element = element
                                , graph = state.graph
                                , showGraph = True
                                , simulation =
                                    initSimulation
                                        state.graph
                                        element.width
                                        element.height
                                , zoom = initZoom element
                                }
                      }
                    , Cmd.none
                    )

                Init graph ->
                    ( { model
                        | graphState =
                            Ready
                                { element = element
                                , graph = graph
                                , showGraph = False
                                , simulation =
                                    initSimulation
                                        graph
                                        element.width
                                        element.height
                                , zoom = initZoom element
                                }
                      }
                    , Cmd.none
                    )

        ReceiveElementPosition (Err _) ->
            ( model, Cmd.none )

        Resize ->
            ( model, getElementPosition )

        Tick ->
            case model.graphState of
                Ready state ->
                    handleTick state

                Init _ ->
                    ( model, Cmd.none )

        ZoomMsg zoomMsg ->
            case model.graphState of
                Ready state ->
                    ( { model | graphState = Ready { state | zoom = Zoom.update zoomMsg state.zoom } }
                    , Cmd.none
                    )

                Init _ ->
                    ( model, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = home shared.translations
    , body = Layout.layout Route.Home_ shared (viewTerms shared model)
    }


viewTerms : Shared.Model -> Model -> List (Element Msg)
viewTerms shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded ->
            [ viewGraph shared.window model ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


elementId : String
elementId =
    "graph"


viewGraph : Shared.Window -> Model -> Element Msg
viewGraph window model =
    let
        zoomEvents : List (TypedSvg.Core.Attribute Msg)
        zoomEvents =
            case model.graphState of
                Init _ ->
                    []

                Ready { zoom } ->
                    Zoom.events zoom ZoomMsg

        zoomTransformAttr : TypedSvg.Core.Attribute Msg
        zoomTransformAttr =
            case model.graphState of
                Init _ ->
                    TypedSvg.Attributes.class []

                Ready { zoom } ->
                    Zoom.transform zoom
    in
    Element.html
        (TypedSvg.svg
            [ TypedSvg.Attributes.id elementId
            , TypedSvg.Attributes.InPx.width (bodyWidth window)
            , TypedSvg.Attributes.InPx.height (bodyHeight window)
            ]
            [ TypedSvg.rect
                (TypedSvg.Attributes.width (TypedSvg.Types.Percent 100)
                    :: TypedSvg.Attributes.height (TypedSvg.Types.Percent 100)
                    :: TypedSvg.Attributes.fill (TypedSvg.Types.Paint Color.white)
                    :: TypedSvg.Attributes.cursor TypedSvg.Types.CursorMove
                    :: zoomEvents
                )
                []
            , TypedSvg.g
                [ zoomTransformAttr ]
                [ renderGraph model ]
            ]
        )


renderGraph : Model -> TypedSvg.Core.Svg Msg
renderGraph model =
    case model.graphState of
        Init _ ->
            TypedSvg.Core.text ""

        Ready { graph, showGraph } ->
            if showGraph then
                TypedSvg.g
                    []
                    [ TypedSvg.g [] (List.map (linkElement graph) (Graph.edges graph))
                    , TypedSvg.g [] (List.map nodeElement (Graph.nodes graph))
                    ]

            else
                TypedSvg.Core.text ""


hexagon : ( Float, Float ) -> Float -> List (TypedSvg.Core.Attribute msg) -> (List (TypedSvg.Core.Svg msg) -> TypedSvg.Core.Svg msg)
hexagon ( x, y ) size attrs =
    let
        angle : Float
        angle =
            2 * pi / 6

        p : TypedSvg.Core.Attribute msg
        p =
            List.range 0 6
                |> List.map toFloat
                |> List.map (\a -> ( x + cos (a * angle) * size, y + sin (a * angle) * size ))
                |> TypedSvg.Attributes.points
    in
    TypedSvg.polygon
        (p :: attrs)


nodeElement : Node Entity -> TypedSvg.Core.Svg Msg
nodeElement node =
    TypedSvg.g []
        [ hexagon ( node.label.x, node.label.y )
            8
            [ TypedSvg.Attributes.fill (TypedSvg.Types.Paint (colorFromScale node.label.x)) ]
            [ TypedSvg.title [] [ TypedSvg.Core.text node.label.value ] ]
        , TypedSvg.text_
            [ TypedSvg.Attributes.InPx.dx node.label.x
            , TypedSvg.Attributes.InPx.dy (node.label.y + 14)
            , TypedSvg.Attributes.alignmentBaseline TypedSvg.Types.AlignmentMiddle
            , TypedSvg.Attributes.textAnchor TypedSvg.Types.AnchorMiddle
            , TypedSvg.Attributes.InPx.fontSize 12
            , TypedSvg.Attributes.fill (TypedSvg.Types.Paint Color.black)
            , TypedSvg.Attributes.pointerEvents "none"
            ]
            [ TypedSvg.Core.text node.label.value ]
        ]


linkElement : Graph Entity () -> Edge () -> TypedSvg.Core.Svg msg
linkElement graph edge =
    let
        retrieveEntity : Maybe { b | node : { a | label : Force.Entity Int { value : String } } } -> Force.Entity Int { value : String }
        retrieveEntity =
            Maybe.withDefault (Force.entity 0 "") << Maybe.map (.node >> .label)

        source : Force.Entity Int { value : String }
        source =
            retrieveEntity (Graph.get edge.from graph)

        target : Force.Entity Int { value : String }
        target =
            retrieveEntity (Graph.get edge.to graph)
    in
    TypedSvg.line
        [ TypedSvg.Attributes.InPx.strokeWidth 1
        , TypedSvg.Attributes.stroke (TypedSvg.Types.Paint (colorFromScale source.x))
        , TypedSvg.Attributes.InPx.x1 source.x
        , TypedSvg.Attributes.InPx.y1 source.y
        , TypedSvg.Attributes.InPx.x2 target.x
        , TypedSvg.Attributes.InPx.y2 target.y
        ]
        []


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        readySubscriptions : ReadyState -> Sub Msg
        readySubscriptions { simulation, zoom } =
            Sub.batch
                [ Zoom.subscriptions zoom ZoomMsg
                , if Force.isCompleted simulation then
                    Sub.none

                  else
                    Events.onAnimationFrame (\_ -> Tick)
                ]
    in
    Sub.batch
        [ case model.graphState of
            Init _ ->
                Sub.none

            Ready state ->
                readySubscriptions state
        , Events.onResize (\_ _ -> Resize)
        ]


loadTerms : Auth.User -> ( Model, Cmd Msg )
loadTerms session =
    let
        graph : Graph Entity ()
        graph =
            Graph.fromNodeLabelsAndEdgePairs [] []
    in
    ( { session = session, state = Loading, selected = Nothing, graphState = Init graph }, Api.send TermsLoaded (termsGraphGet session.token) )


getElementPosition : Cmd Msg
getElementPosition =
    Task.attempt ReceiveElementPosition (Dom.getElement elementId)
