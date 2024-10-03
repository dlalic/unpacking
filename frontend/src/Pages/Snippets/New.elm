module Pages.Snippets.New exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (AuthorResponse, CreateSnippet, TermResponse)
import Api.Request.Default exposing (createSnippets, readAllAuthors, readAllTerms)
import Auth
import Common exposing (uuidFromString)
import Dict
import Element exposing (Element, text)
import Forms.SnippetForm exposing (NewSnippet, defaultNew, newForm, newSnippetValidator)
import Forms.Validators exposing (ValidationField)
import Gen.Route as Route
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import SearchBox exposing (ChangeEvent(..))
import Set exposing (Set)
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (newSnippet)
import Translations.Forms as Forms
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
    , terms : Maybe (List TermResponse)
    , authors : Maybe (List AuthorResponse)
    , toCreate : NewSnippet
    , authorsDropdown : Dropdown
    , termsDropdown : Dropdown
    }


type State
    = Loading
    | Loaded ( List TermResponse, List AuthorResponse )
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    loadTerms session


type Msg
    = TermsLoaded (Result Http.Error (List TermResponse))
    | AuthorsLoaded (Result Http.Error (List AuthorResponse))
    | Edit NewSnippet
    | ChangedAuthorsDropdown (ChangeEvent AuthorResponse)
    | ChangedTermsDropdown (ChangeEvent TermResponse)
    | ClickedCancel
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewSnippet))
    | Created (Result Http.Error Uuid)


update : Request -> Storage -> Msg -> Model -> ( Model, Cmd Msg )
update req storage msg model =
    case msg of
        TermsLoaded (Ok list) ->
            case model.authors of
                Just b ->
                    ( { model | state = Loaded ( list, b ) }, Cmd.none )

                _ ->
                    ( { model | terms = Just list }, Cmd.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        AuthorsLoaded (Ok list) ->
            case model.terms of
                Just a ->
                    ( { model | state = Loaded ( a, list ) }, Cmd.none )

                _ ->
                    ( { model | authors = Just list }, Cmd.none )

        AuthorsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        Edit new ->
            ( { model | toCreate = new }, Cmd.none )

        ClickedCancel ->
            ( model, Request.pushRoute Route.Snippets req )

        ClickedSubmit (Ok input) ->
            let
                valid : NewSnippet
                valid =
                    fromValid input

                new : Set String
                new =
                    Set.fromList (String.split "," model.authorsDropdown.text)

                existing : Set String
                existing =
                    Set.fromList (Dict.values valid.authors)

                diff : Set String
                diff =
                    Set.diff new existing

                newSnippet : CreateSnippet
                newSnippet =
                    { text = valid.text
                    , media = valid.media
                    , link = valid.link
                    , existingAuthors = List.concatMap uuidFromString (Dict.keys valid.authors)
                    , newAuthors = List.filter (\v -> String.length v > 0) (Set.toList diff)
                    , terms = List.concatMap uuidFromString (Dict.keys valid.terms)
                    }
            in
            createSnippet model newSnippet

        ClickedSubmit (Err list) ->
            let
                toCreate : NewSnippet -> NewSnippet
                toCreate snippet =
                    { snippet | errors = list }
            in
            ( { model | toCreate = toCreate model.toCreate }, Cmd.none )

        Created (Ok _) ->
            ( model, Request.pushRoute Route.Snippets req )

        Created (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ChangedAuthorsDropdown changeEvent ->
            let
                toCreate : NewSnippet
                toCreate =
                    model.toCreate
            in
            case changeEvent of
                SelectionChanged sth ->
                    ( { model | authorsDropdown = updateModel changeEvent model.authorsDropdown, toCreate = { toCreate | authors = Dict.insert (Uuid.toString sth.id) sth.name model.toCreate.authors } }, Cmd.none )

                _ ->
                    ( { model | authorsDropdown = updateModel changeEvent model.authorsDropdown }, Cmd.none )

        ChangedTermsDropdown changeEvent ->
            let
                toCreate : NewSnippet
                toCreate =
                    model.toCreate
            in
            case changeEvent of
                SelectionChanged sth ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown, toCreate = { toCreate | terms = Dict.insert (Uuid.toString sth.id) sth.name model.toCreate.terms } }, Cmd.none )

                _ ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown }, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = newSnippet shared.translations
    , body = Layout.layout Route.Snippets__New shared (viewForm shared model)
    }


viewForm : Shared.Model -> Model -> List (Element Msg)
viewForm shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded ( terms, authors ) ->
            let
                submit : Msg
                submit =
                    ClickedSubmit (validate (newSnippetValidator shared.translations) model.toCreate)

                aDropdown : Element Msg
                aDropdown =
                    dropdown (Forms.authors shared.translations) model.authorsDropdown authors ChangedAuthorsDropdown []

                tDropdown : Element Msg
                tDropdown =
                    dropdown (Forms.terms shared.translations) model.termsDropdown terms ChangedTermsDropdown []
            in
            [ newForm shared.translations model.toCreate aDropdown tDropdown Edit ClickedCancel submit ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


createSnippet : Model -> CreateSnippet -> ( Model, Cmd Msg )
createSnippet model snippet =
    ( { model | state = Loading }, Api.send Created (createSnippets snippet model.session.token) )


loadTerms : Auth.User -> ( Model, Cmd Msg )
loadTerms session =
    let
        initial : Model
        initial =
            { session = session
            , state = Loading
            , terms = Nothing
            , authors = Nothing
            , toCreate = defaultNew
            , termsDropdown = initModel
            , authorsDropdown = initModel
            }
    in
    ( initial, Cmd.batch [ Api.send TermsLoaded (readAllTerms session.token), Api.send AuthorsLoaded (readAllAuthors session.token) ] )
