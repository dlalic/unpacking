module Pages.Terms.New exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (CreateTerm, TermResponse)
import Api.Request.Default exposing (createTerms, readAllTerms)
import Auth
import Common exposing (uuidFromString)
import Dict
import Effect exposing (Effect)
import Element exposing (Element, text)
import Forms.TermForm exposing (NewTerm, defaultNew, newForm, newTermValidator)
import Forms.Validators exposing (ValidationField)
import Http
import Layouts
import Page exposing (Page)
import Problem exposing (isUnauthenticated)
import Route exposing (Route)
import Route.Path
import SearchBox exposing (ChangeEvent(..))
import Shared
import Translations.Buttons exposing (newTerm)
import Translations.Forms exposing (related)
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
    , toCreate : NewTerm
    , termsDropdown : Dropdown
    }


type State
    = Loading
    | Loaded (List TermResponse)
    | Errored String


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    loadTerms user



-- UPDATE


type Msg
    = TermsLoaded (Result Http.Error (List TermResponse))
    | Edit NewTerm
    | ChangedDropdown (ChangeEvent TermResponse)
    | ClickedCancel
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewTerm))
    | Created (Result Http.Error Uuid)


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        TermsLoaded (Ok list) ->
            ( { model | state = Loaded list }, Effect.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        Edit new ->
            ( { model | toCreate = new }, Effect.none )

        ClickedCancel ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Terms
                , query = Dict.empty
                , hash = Nothing
                }
            )

        ClickedSubmit (Ok input) ->
            let
                valid : NewTerm
                valid =
                    fromValid input
            in
            createTerm user model { name = valid.name, related = List.concatMap uuidFromString (Dict.keys valid.related) }

        ClickedSubmit (Err list) ->
            let
                toCreate : NewTerm
                toCreate =
                    model.toCreate
            in
            ( { model | toCreate = { toCreate | errors = list } }, Effect.none )

        Created (Ok _) ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Terms
                , query = Dict.empty
                , hash = Nothing
                }
            )

        Created (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        ChangedDropdown changeEvent ->
            let
                toCreate : NewTerm
                toCreate =
                    model.toCreate
            in
            case changeEvent of
                SelectionChanged sth ->
                    ( { model | termsDropdown = updateModel (TextChanged "") model.termsDropdown, toCreate = { toCreate | related = Dict.insert (Uuid.toString sth.id) sth.name model.toCreate.related } }, Effect.none )

                _ ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = newTerm shared.translations
    , elements = viewForm shared model
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


loadTerms : Auth.User -> ( Model, Effect Msg )
loadTerms session =
    ( { state = Loading, toCreate = defaultNew, termsDropdown = initModel }
    , Effect.sendCmd (Api.send TermsLoaded (readAllTerms session.token))
    )


createTerm : Auth.User -> Model -> CreateTerm -> ( Model, Effect Msg )
createTerm user model term =
    ( { model | state = Loading }
    , Effect.sendCmd (Api.send Created (createTerms term user.token))
    )



-- SUBSCRIPTIONS
