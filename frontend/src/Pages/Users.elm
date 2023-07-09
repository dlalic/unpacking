module Pages.Users exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (Role(..), UpdateUser, UserResponse)
import Api.Request.Default exposing (deleteUsers, readAllUsers, updateUsers)
import Auth
import Element exposing (Element, text)
import Forms.UserForm exposing (EditUser, editForm, editUserValidator, stringFromRole)
import Forms.Validators exposing (ValidationField)
import Gen.Route as Route
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (delete, edit, newUser)
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (users)
import UI.Button exposing (defaultButton)
import UI.Card exposing (keyedCard)
import UI.Dialog exposing (defaultDialog)
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
    , toUpdate : Maybe EditUser
    , toDelete : Maybe Uuid
    }


type State
    = Loading
    | Loaded (List UserResponse)
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    loadUsers session


type Msg
    = UsersLoaded (Result Http.Error (List UserResponse))
    | UserDeleted (Result Http.Error ())
    | UserUpdated (Result Http.Error ())
    | ClickedNew
    | Edit EditUser
    | ClickedCancelEdit
    | ClickedSubmitEdit (Result (List ( ValidationField, String )) (Valid EditUser))
    | ClickedDelete Uuid
    | ClickedCancelDelete
    | ClickedSubmitDelete


update : Request -> Storage -> Msg -> Model -> ( Model, Cmd Msg )
update req storage msg model =
    case msg of
        UsersLoaded (Ok list) ->
            ( { model | state = Loaded list }, Cmd.none )

        UsersLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ClickedNew ->
            ( model, Request.pushRoute Route.Users__New req )

        Edit user ->
            ( { model | toUpdate = Just user }, Cmd.none )

        ClickedCancelEdit ->
            ( { model | toUpdate = Nothing }, Cmd.none )

        ClickedSubmitEdit (Ok input) ->
            let
                valid : EditUser
                valid =
                    fromValid input
            in
            updateUser model.session valid.id { name = valid.name, email = valid.email, role = valid.role }

        ClickedSubmitEdit (Err list) ->
            case model.toUpdate of
                Just some ->
                    ( { model | toUpdate = Just { some | errors = list } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UserUpdated (Ok _) ->
            loadUsers model.session

        UserUpdated (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ClickedDelete uuid ->
            ( { model | toDelete = Just uuid }, Cmd.none )

        ClickedCancelDelete ->
            ( { model | toDelete = Nothing }, Cmd.none )

        ClickedSubmitDelete ->
            case model.toDelete of
                Just uuid ->
                    deleteUser model.session uuid

                Nothing ->
                    ( model, Cmd.none )

        UserDeleted (Ok _) ->
            loadUsers model.session

        UserDeleted (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = users shared.translations
    , body = Layout.layout Route.Users shared (viewUsers shared model)
    }


viewUsers : Shared.Model -> Model -> List (Element Msg)
viewUsers shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded list ->
            case ( model.toUpdate, model.toDelete ) of
                ( Just toUpdate, _ ) ->
                    [ editUser shared toUpdate ]

                ( _, Just _ ) ->
                    [ defaultDialog shared.translations ClickedCancelDelete ClickedSubmitDelete ]

                _ ->
                    defaultButton (newUser shared.translations) ClickedNew :: List.map (viewUser shared) list

        Errored reason ->
            [ text (onError shared.translations reason) ]


viewUser : Shared.Model -> UserResponse -> Element Msg
viewUser shared user =
    let
        rightLabel : String
        rightLabel =
            case user.role of
                RoleAdmin ->
                    stringFromRole shared.translations user.role

                _ ->
                    ""

        buttons : List (Element Msg)
        buttons =
            [ defaultButton (edit shared.translations) (Edit (editUserFromUser user))
            , defaultButton (delete shared.translations) (ClickedDelete user.id)
            ]
    in
    keyedCard { title = user.name, rightLabel = rightLabel, body = [], onClick = Nothing, buttons = buttons } user.id


editUser : Shared.Model -> EditUser -> Element Msg
editUser shared user =
    let
        submit : Msg
        submit =
            ClickedSubmitEdit (validate (editUserValidator shared.translations) user)
    in
    editForm shared.translations user Edit ClickedCancelEdit submit


deleteUser : Auth.User -> Uuid -> ( Model, Cmd Msg )
deleteUser session uuid =
    ( { session = session, state = Loading, toUpdate = Nothing, toDelete = Nothing }
    , Api.send UserDeleted (deleteUsers uuid session.token)
    )


updateUser : Auth.User -> Uuid -> UpdateUser -> ( Model, Cmd Msg )
updateUser session id user =
    ( { session = session, state = Loading, toUpdate = Nothing, toDelete = Nothing }
    , Api.send UserUpdated (updateUsers id user session.token)
    )


loadUsers : Auth.User -> ( Model, Cmd Msg )
loadUsers session =
    ( { session = session, state = Loading, toUpdate = Nothing, toDelete = Nothing }
    , Api.send UsersLoaded (readAllUsers session.token)
    )


editUserFromUser : UserResponse -> EditUser
editUserFromUser model =
    { id = model.id
    , title = model.name
    , name = model.name
    , email = model.email
    , role = model.role
    , errors = []
    }
