CREATE TABLE authors_snippets (
   author_id UUID REFERENCES authors(id),
   snippet_id UUID REFERENCES snippets(id),
   PRIMARY KEY(author_id, snippet_id)
);