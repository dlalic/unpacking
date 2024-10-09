module Pages.Snippets.New exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (AuthorResponse, CreateSnippet, TermResponse)
import Api.Request.Default exposing (createSnippets, readAllAuthors, readAllTerms)
import Auth
import Common exposing (uuidFromString)
import Dict
import Effect exposing (Effect)
import Element exposing (Element, text)
import Forms.SnippetForm exposing (NewSnippet, defaultNew, newForm, newSnippetValidator)
import Forms.Validators exposing (ValidationField)
import Http
import Layouts
import Page exposing (Page)
import Problem exposing (isUnauthenticated)
import Route exposing (Route)
import Route.Path
import SearchBox exposing (ChangeEvent(..))
import Set exposing (Set)
import Shared
import Translations.Buttons exposing (newSnippet)
import Translations.Forms as Forms
import Translations.Labels exposing (loading, onError)
import UI.Dropdown exposing (Dropdown, dropdown, initModel, updateModel)
import Uuid exposing (Uuid)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user
        , update = update user
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


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    loadTerms user



-- UPDATE


type Msg
    = TermsLoaded (Result Http.Error (List TermResponse))
    | AuthorsLoaded (Result Http.Error (List AuthorResponse))
    | Edit NewSnippet
    | ChangedAuthorsDropdown (ChangeEvent AuthorResponse)
    | ChangedTermsDropdown (ChangeEvent TermResponse)
    | ClickedCancel
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewSnippet))
    | Created (Result Http.Error Uuid)


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        TermsLoaded (Ok list) ->
            case model.authors of
                Just b ->
                    ( { model | state = Loaded ( list, b ) }, Effect.none )

                _ ->
                    ( { model | terms = Just list }, Effect.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        AuthorsLoaded (Ok list) ->
            case model.terms of
                Just a ->
                    ( { model | state = Loaded ( a, list ) }, Effect.none )

                _ ->
                    ( { model | authors = Just list }, Effect.none )

        AuthorsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        Edit new ->
            ( { model | toCreate = new }, Effect.none )

        ClickedCancel ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Snippets
                , query = Dict.empty
                , hash = Nothing
                }
            )

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
            createSnippet user model newSnippet

        ClickedSubmit (Err list) ->
            let
                toCreate : NewSnippet -> NewSnippet
                toCreate snippet =
                    { snippet | errors = list }
            in
            ( { model | toCreate = toCreate model.toCreate }, Effect.none )

        Created (Ok _) ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Snippets
                , query = Dict.empty
                , hash = Nothing
                }
            )

        Created (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        ChangedAuthorsDropdown changeEvent ->
            let
                toCreate : NewSnippet
                toCreate =
                    model.toCreate
            in
            case changeEvent of
                SelectionChanged sth ->
                    ( { model | authorsDropdown = updateModel changeEvent model.authorsDropdown, toCreate = { toCreate | authors = Dict.insert (Uuid.toString sth.id) sth.name model.toCreate.authors } }, Effect.none )

                _ ->
                    ( { model | authorsDropdown = updateModel changeEvent model.authorsDropdown }, Effect.none )

        ChangedTermsDropdown changeEvent ->
            let
                toCreate : NewSnippet
                toCreate =
                    model.toCreate
            in
            case changeEvent of
                SelectionChanged sth ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown, toCreate = { toCreate | terms = Dict.insert (Uuid.toString sth.id) sth.name model.toCreate.terms } }, Effect.none )

                _ ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = newSnippet shared.translations
    , elements = viewForm shared model
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


createSnippet : Auth.User -> Model -> CreateSnippet -> ( Model, Effect Msg )
createSnippet user model snippet =
    ( { model | state = Loading }
    , Effect.sendCmd (Api.send Created (createSnippets snippet user.token))
    )


loadTerms : Auth.User -> ( Model, Effect Msg )
loadTerms user =
    let
        initial : Model
        initial =
            { state = Loading
            , terms = Nothing
            , authors = Nothing
            , toCreate = defaultNew
            , termsDropdown = initModel
            , authorsDropdown = initModel
            }
    in
    ( initial
    , Effect.batch
        [ Effect.sendCmd (Api.send TermsLoaded (readAllTerms user.token))
        , Effect.sendCmd (Api.send AuthorsLoaded (readAllAuthors user.token))
        ]
    )



-- SUBSCRIPTIONS
