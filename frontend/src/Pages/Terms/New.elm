module Pages.Terms.New exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (CreateTerm, TermResponse)
import Api.Request.Default exposing (createTerms, readAllTerms)
import Auth
import Common exposing (uuidFromString)
import Dict
import Element exposing (Element, text)
import Forms.TermForm exposing (NewTerm, defaultNew, newForm, newTermValidator)
import Forms.Validators exposing (ValidationField)
import Gen.Route as Route
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import SearchBox exposing (ChangeEvent(..))
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (newTerm)
import Translations.Forms exposing (related)
import Translations.Labels exposing (loading, onError)
import UI.Dropdown exposing (Dropdown, dropdown, initModel, updateModel)
import UI.Layout as Layout
import Uuid exposing (Uuid)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Shared.Model -> Request -> Page.With Model Msg
page shared req =
    Page.protected.element
        (\session ->
            { init = init session
            , update = update req shared.storage
            , view = view shared
            , subscriptions = \_ -> Sub.none
            }
        )


type alias Model =
    { session : Auth.User
    , state : State
    , toCreate : NewTerm
    , termsDropdown : Dropdown TermResponse
    }


type State
    = Loading
    | Loaded (List TermResponse)
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    loadTerms session


type Msg
    = TermsLoaded (Result Http.Error (List TermResponse))
    | Edit NewTerm
    | ChangedDropdown (ChangeEvent TermResponse)
    | ClickedCancel
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewTerm))
    | Created (Result Http.Error Uuid)


update : Request -> Storage -> Msg -> Model -> ( Model, Cmd Msg )
update req storage msg model =
    case msg of
        TermsLoaded (Ok list) ->
            ( { model | state = Loaded list }, Cmd.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        Edit new ->
            ( { model | toCreate = new }, Cmd.none )

        ClickedCancel ->
            ( model, Request.pushRoute Route.Terms req )

        ClickedSubmit (Ok input) ->
            let
                valid : NewTerm
                valid =
                    fromValid input
            in
            createTerm model { name = valid.name, related = List.concatMap uuidFromString (Dict.keys valid.related) }

        ClickedSubmit (Err list) ->
            let
                toCreate : NewTerm
                toCreate =
                    model.toCreate
            in
            ( { model | toCreate = { toCreate | errors = list } }, Cmd.none )

        Created (Ok _) ->
            ( model, Request.pushRoute Route.Terms req )

        Created (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ChangedDropdown changeEvent ->
            let
                toCreate : NewTerm
                toCreate =
                    model.toCreate
            in
            case changeEvent of
                SelectionChanged sth ->
                    ( { model | termsDropdown = updateModel (TextChanged "") model.termsDropdown, toCreate = { toCreate | related = Dict.insert (Uuid.toString sth.id) sth.name model.toCreate.related } }, Cmd.none )

                _ ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown }, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = newTerm shared.translations
    , body = Layout.layout Route.Terms__New shared (viewForm shared model)
    }


viewForm : Shared.Model -> Model -> List (Element Msg)
viewForm shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded terms ->
            let
                submit : Msg
                submit =
                    ClickedSubmit (validate (newTermValidator shared.translations) model.toCreate)

                dd : Element Msg
                dd =
                    dropdown (related shared.translations) model.termsDropdown terms ChangedDropdown []
            in
            [ newForm shared.translations model.toCreate dd Edit ClickedCancel submit ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


loadTerms : Auth.User -> ( Model, Cmd Msg )
loadTerms session =
    ( { session = session, state = Loading, toCreate = defaultNew, termsDropdown = initModel }, Api.send TermsLoaded (readAllTerms session.token) )


createTerm : Model -> CreateTerm -> ( Model, Cmd Msg )
createTerm model term =
    ( { model | state = Loading }, Api.send Created (createTerms term model.session.token) )
