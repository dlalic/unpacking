module Pages.SignIn exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (CreateToken, TokenResponse)
import Api.Request.Default exposing (createAuth)
import Element exposing (Element, text)
import Forms.SignInForm exposing (NewSignIn, defaultNew, newForm, newSignInValidator)
import Forms.Validators exposing (ValidationField)
import Gen.Params.SignIn exposing (Params)
import Gen.Route as Route
import Http
import Page
import Problem
import Request
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (signIn)
import Translations.Labels exposing (loading, onError)
import UI.Layout as Layout
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Shared.Model -> Request.With Params -> Page.With Model Msg
page shared _ =
    Page.element
        { init = init
        , update = update shared.storage
        , view = view shared
        , subscriptions = \_ -> Sub.none
        }


type alias Model =
    { state : State
    , toCreate : NewSignIn
    }


type State
    = Loading
    | Loaded
    | Errored String


init : ( Model, Cmd Msg )
init =
    ( { state = Loaded, toCreate = defaultNew }, Cmd.none )


type Msg
    = Edit NewSignIn
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewSignIn))
    | TokenLoaded (Result Http.Error TokenResponse)


update : Storage -> Msg -> Model -> ( Model, Cmd Msg )
update storage msg model =
    case msg of
        Edit new ->
            ( { model | toCreate = new }, Cmd.none )

        ClickedSubmit (Ok input) ->
            let
                valid : NewSignIn
                valid =
                    fromValid input
            in
            login model { email = valid.email, password = valid.password }

        ClickedSubmit (Err list) ->
            let
                toCreate : NewSignIn
                toCreate =
                    model.toCreate
            in
            ( { model | toCreate = { toCreate | errors = list } }, Cmd.none )

        TokenLoaded (Ok response) ->
            ( model, Storage.signIn { token = response.token, id = response.id, role = response.role } storage )

        TokenLoaded (Err err) ->
            ( { model | state = Errored (Problem.toString err) }, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = signIn shared.translations
    , body = Layout.layout Route.SignIn shared (viewSignIn shared model)
    }


viewSignIn : Shared.Model -> Model -> List (Element Msg)
viewSignIn shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded ->
            let
                submit : Msg
                submit =
                    ClickedSubmit (validate (newSignInValidator shared.translations) model.toCreate)
            in
            [ newForm shared.translations model.toCreate Edit submit ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


login : Model -> CreateToken -> ( Model, Cmd Msg )
login model request =
    ( { model | state = Loading }, Api.send TokenLoaded (createAuth request) )
