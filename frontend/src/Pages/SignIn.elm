module Pages.SignIn exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (CreateToken, TokenResponse)
import Api.Request.Default exposing (createAuth)
import Effect exposing (Effect)
import Element exposing (Element, text)
import Forms.SignInForm exposing (NewSignIn, defaultNew, newForm, newSignInValidator)
import Forms.Validators exposing (ValidationField)
import Http
import Layouts
import Page exposing (Page)
import Problem
import Route exposing (Route)
import Shared
import Translations.Buttons exposing (signIn)
import Translations.Labels exposing (loading, onError)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared _ =
    Page.new
        { init = init
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
    , toCreate : NewSignIn
    }


type State
    = Loading
    | Loaded
    | Errored String


init : () -> ( Model, Effect Msg )
init () =
    ( { state = Loaded, toCreate = defaultNew }, Effect.none )



-- UPDATE


type Msg
    = Edit NewSignIn
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewSignIn))
    | TokenLoaded (Result Http.Error TokenResponse)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        Edit new ->
            ( { model | toCreate = new }, Effect.none )

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
            ( { model | toCreate = { toCreate | errors = list } }, Effect.none )

        TokenLoaded (Ok response) ->
            ( model, Effect.signIn { token = response.token, id = response.id, role = response.role } )

        TokenLoaded (Err err) ->
            ( { model | state = Errored (Problem.toString err) }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = signIn shared.translations
    , elements = viewSignIn shared model
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


login : Model -> CreateToken -> ( Model, Effect Msg )
login model request =
    ( { model | state = Loading }, Effect.sendCmd (Api.send TokenLoaded (createAuth request)) )



-- SUBSCRIPTIONS
