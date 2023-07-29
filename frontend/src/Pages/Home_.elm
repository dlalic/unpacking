module Pages.Home_ exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (TermGraphResponse)
import Api.Request.Default exposing (termsGraphGet)
import Auth
import Color
import Element exposing (Element, centerX, el, text)
import Force
import Gen.Route as Route
import Graph exposing (Edge, Graph, Node, NodeContext, NodeId)
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import Shared
import Storage exposing (Storage)
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (home)
import TypedSvg exposing (g, line, polygon, svg, title)
import TypedSvg.Attributes exposing (class, color, fill, points, stroke, viewBox)
import TypedSvg.Attributes.InPx exposing (strokeWidth, x1, x2, y1, y2)
import TypedSvg.Core exposing (Attribute, Svg)
import TypedSvg.Events exposing (onClick)
import TypedSvg.Types exposing (Paint(..), px)
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
    { session : Auth.User
    , state : State
    , selected : Maybe String
    }


type State
    = Loading
    | Loaded TermGraphResponse
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    loadTerms session


type Msg
    = TermsLoaded (Result Http.Error TermGraphResponse)
    | TermSelected String


update : Storage -> Msg -> Model -> ( Model, Cmd Msg )
update storage msg model =
    case msg of
        TermsLoaded (Ok response) ->
            ( { model | state = Loaded response }, Cmd.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        TermSelected term ->
            ( { model | selected = Just term }, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = home shared.translations
    , body = Layout.layout Route.Home_ shared (viewUser shared model)
    }


viewUser : Shared.Model -> Model -> List (Element Msg)
viewUser shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded response ->
            case model.selected of
                Just v ->
                    [ el [ centerX ] (text v), graphView shared.window response ]

                _ ->
                    [ graphView shared.window response ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


loadTerms : Auth.User -> ( Model, Cmd Msg )
loadTerms session =
    ( { session = session, state = Loading, selected = Nothing }, Api.send TermsLoaded (termsGraphGet session.token) )


linkElement : Graph Entity () -> Edge () -> Svg msg
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
    line
        [ strokeWidth 1
        , stroke (Paint (colorFromScale source.x))
        , x1 source.x
        , y1 source.y
        , x2 target.x
        , y2 target.y
        ]
        []


hexagon : ( Float, Float ) -> Float -> List (Attribute msg) -> (List (Svg msg) -> Svg msg)
hexagon ( x, y ) size attrs =
    let
        angle : Float
        angle =
            2 * pi / 6

        p : Attribute msg
        p =
            List.range 0 6
                |> List.map toFloat
                |> List.map (\a -> ( x + cos (a * angle) * size, y + sin (a * angle) * size ))
                |> points
    in
    polygon
        (p :: attrs)


nodeSize : Float -> Entity -> Svg Msg
nodeSize size node =
    hexagon ( node.x, node.y )
        size
        [ fill (Paint (colorFromScale node.x))
        , onClick (TermSelected node.value)
        ]
        [ title [ color (Color.rgb255 0 0 0) ] [ TypedSvg.Core.text node.value ] ]


nodeElement : Node Entity -> Svg Msg
nodeElement node =
    nodeSize 8 node.label


textElement : Float -> Float -> Node Entity -> Svg Msg
textElement width height node =
    let
        x : Float
        x =
            if node.label.x < width / 2 then
                node.label.x - toFloat (String.length node.label.value) * 7 - 10

            else
                node.label.x + 10

        y : Float
        y =
            if node.label.y < height / 2 then
                node.label.y - 5

            else
                node.label.y + 10
    in
    TypedSvg.text_
        [ TypedSvg.Attributes.x (px x)
        , TypedSvg.Attributes.y (px y)
        , TypedSvg.Attributes.fontFamily [ "monospace" ]
        , TypedSvg.Attributes.fontSize (px 12)
        ]
        [ TypedSvg.Core.text node.label.value ]


type alias Entity =
    Force.Entity NodeId { value : String }


updateGraphWithList : Graph Entity () -> List Entity -> Graph Entity ()
updateGraphWithList =
    let
        graphUpdater : Entity -> Maybe (NodeContext Entity ()) -> Maybe (NodeContext Entity ())
        graphUpdater value =
            Maybe.map (\ctx -> updateContextWithValue ctx value)
    in
    List.foldr (\node graph -> Graph.update node.id (graphUpdater node) graph)


updateContextWithValue : NodeContext Entity () -> Entity -> NodeContext Entity ()
updateContextWithValue nodeCtx value =
    let
        node : Node Entity
        node =
            nodeCtx.node
    in
    { nodeCtx | node = { node | label = value } }


tuple : List Int -> ( Int, Int )
tuple input =
    case input of
        [ a, b ] ->
            ( a, b )

        _ ->
            ( 0, 0 )


graphView : Shared.Window -> TermGraphResponse -> Element Msg
graphView window response =
    let
        w : Float
        w =
            toFloat (min window.width 1024)

        h : Float
        h =
            toFloat 480

        graph : Graph (Force.Entity Int { value : String }) ()
        graph =
            Graph.mapContexts
                (\({ incoming, outgoing } as ctx) ->
                    { incoming = incoming
                    , outgoing = outgoing
                    , node = { label = Force.entity ctx.node.id ctx.node.label, id = ctx.node.id }
                    }
                )
                (Graph.fromNodeLabelsAndEdgePairs response.terms (List.map tuple response.nodes))

        links : List { source : NodeId, target : NodeId, distance : Float, strength : Maybe a }
        links =
            graph
                |> Graph.edges
                |> List.map
                    (\{ from, to } ->
                        { source = from
                        , target = to
                        , distance = w / 12
                        , strength = Nothing
                        }
                    )

        forces : List (Force.Force NodeId)
        forces =
            [ Force.customLinks 1 links
            , Force.manyBodyStrength -80 (List.map .id (Graph.nodes graph))
            , Force.center (w / 2) (h / 2)
            ]

        model : Graph Entity ()
        model =
            Graph.nodes graph
                |> List.map .label
                |> Force.computeSimulation (Force.simulation forces)
                |> updateGraphWithList graph
    in
    Element.html
        (svg [ viewBox 0 0 w h ]
            [ g [ class [ "links" ] ] (List.map (linkElement model) (Graph.edges model))
            , g [ class [ "nodes" ] ] (List.map nodeElement (Graph.nodes model))
            , g [ class [ "texts" ] ] (List.map (textElement w h) (Graph.nodes model))
            ]
        )
