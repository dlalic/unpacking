-- Do not manually edit this file, it was auto-generated by yonigibbs/elm-i18next-gen
-- https://github.com/yonigibbs/elm-i18next-gen


module Translations.Forms exposing (..)

import I18Next exposing (Delims(..), Translations, t, tr)


authors : Translations -> String
authors translations =
    t translations "forms.authors"


edit : Translations -> String -> String
edit translations sth =
    tr translations Curly "forms.edit" [ ( "sth", sth ) ]


link : Translations -> String
link translations =
    t translations "forms.link"


media : Translations -> String
media translations =
    t translations "forms.media"


mediaBlog : Translations -> String
mediaBlog translations =
    t translations "forms.media_blog"


mediaBook : Translations -> String
mediaBook translations =
    t translations "forms.media_book"


mediaNews : Translations -> String
mediaNews translations =
    t translations "forms.media_news"


mediaTwitter : Translations -> String
mediaTwitter translations =
    t translations "forms.media_twitter"


mediaVideo : Translations -> String
mediaVideo translations =
    t translations "forms.media_video"


mediaWebsite : Translations -> String
mediaWebsite translations =
    t translations "forms.media_website"


name : Translations -> String
name translations =
    t translations "forms.name"


onLengthLessThan : Translations -> String -> String
onLengthLessThan translations n =
    tr translations Curly "forms.on_length_less_than" [ ( "n", n ) ]


onNameEmpty : Translations -> String
onNameEmpty translations =
    t translations "forms.on_name_empty"


onPasswordEmpty : Translations -> String
onPasswordEmpty translations =
    t translations "forms.on_password_empty"


onSnippetEmpty : Translations -> String
onSnippetEmpty translations =
    t translations "forms.on_snippet_empty"


onUsernameEmpty : Translations -> String
onUsernameEmpty translations =
    t translations "forms.on_username_empty"


password : Translations -> String
password translations =
    t translations "forms.password"


role : Translations -> String
role translations =
    t translations "forms.role"


roleAdmin : Translations -> String
roleAdmin translations =
    t translations "forms.role_admin"


roleUser : Translations -> String
roleUser translations =
    t translations "forms.role_user"


related : Translations -> String
related translations =
    t translations "forms.related"


text : Translations -> String
text translations =
    t translations "forms.text"


terms : Translations -> String
terms translations =
    t translations "forms.terms"


username : Translations -> String
username translations =
    t translations "forms.username"
