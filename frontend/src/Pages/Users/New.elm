module Pages.Users.New exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (CreateUser)
import Api.Request.Default exposing (createUsers)
import Auth
import Element exposing (Element, text)
import Forms.UserForm exposing (NewUser, defaultNew, newForm, newUserValidator)
import Forms.Validators exposing (ValidationField)
import Gen.Route as Route
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (newUser)
import Translations.Labels exposing (loading, onError)
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
    , toCreate : NewUser
    }


type State
    = Loading
    | Loaded
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    ( { session = session, state = Loaded, toCreate = defaultNew }, Cmd.none )


type Msg
    = Edit NewUser
    | ClickedCancel
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewUser))
    | Created (Result Http.Error Uuid)


update : Request -> Storage -> Msg -> Model -> ( Model, Cmd Msg )
update req storage msg model =
    case msg of
        Edit new ->
            ( { model | toCreate = new }, Cmd.none )

        ClickedCancel ->
            ( model, Request.pushRoute Route.Users req )

        ClickedSubmit (Ok input) ->
            createUser model (fromValid input)

        ClickedSubmit (Err list) ->
            let
                toCreate : NewUser -> NewUser
                toCreate user =
                    { user | errors = list }
            in
            ( { model | toCreate = toCreate model.toCreate }, Cmd.none )

        Created (Ok _) ->
            ( model, Request.pushRoute Route.Users req )

        Created (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = newUser shared.translations
    , body = Layout.layout Route.Users__New shared (viewForm shared model)
    }


viewForm : Shared.Model -> Model -> List (Element Msg)
viewForm shared model =
    let
        submit : Msg
        submit =
            ClickedSubmit (validate (newUserValidator shared.translations) model.toCreate)
    in
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded ->
            [ newForm shared.translations model.toCreate Edit ClickedCancel submit ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


createUser : Model -> NewUser -> ( Model, Cmd Msg )
createUser model user =
    ( { model | state = Loading }, Api.send Created (createUsers (createUserFrom user) model.session.token) )


createUserFrom : NewUser -> CreateUser
createUserFrom model =
    { name = model.name
    , role = model.role
    , email = model.email
    , password = model.password
    }
