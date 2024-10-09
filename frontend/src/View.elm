module View exposing
    ( View, map
    , none, fromString
    , toBrowserDocument
    )

{-|

@docs View, map
@docs none, fromString
@docs toBrowserDocument

-}

import Browser
import Element exposing (centerX, column, fill, height)
import Element.Font as Font
import Route exposing (Route)
import Shared.Model
import UI.Dimensions exposing (fillMaxViewWidth)


type alias View msg =
    { title : String
    , elements : List (Element.Element msg)
    }


{-| Used internally by Elm Land to create your application
so it works with Elm's expected `Browser.Document msg` type.
-}
toBrowserDocument :
    { shared : Shared.Model.Model
    , route : Route ()
    , view : View msg
    }
    -> Browser.Document msg
toBrowserDocument { view } =
    { title = view.title
    , body = [ Element.layout [ Font.family [ Font.typeface "Public Sans", Font.sansSerif ] ] (column [ fillMaxViewWidth, height fill, centerX ] view.elements) ]
    }


{-| Used internally by Elm Land to connect your pages together.
-}
map : (msg1 -> msg2) -> View msg1 -> View msg2
map fn view =
    { title = view.title
    , elements = List.map (Element.map fn) view.elements
    }


{-| Used internally by Elm Land whenever transitioning between
authenticated pages.
-}
none : View msg
none =
    { title = ""
    , elements = []
    }


{-| If you customize the `View` module, anytime you run `elm-land add page`,
the generated page will use this when adding your `view` function.

That way your app will compile after adding new pages, and you can see
the new page working in the web browser!

-}
fromString : String -> View msg
fromString moduleName =
    { title = moduleName
    , elements = [ Element.text moduleName ]
    }
