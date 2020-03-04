# Aspen

Aspen is a simple markup language that transforms simple narrative information into rich graph data for use in Neo4j.

To put it another way, Aspen is a simple language that compiles to Cypher, specifically for use in creating graph data.

Aspen transforms this:

```
(Matt) [knows] (Brianna)
```

into this:

```
(Person {name: "Matt"})-[:KNOWS]->(Person {name: "Brianna"})
```

(It's only slightly more complicated than that.)


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aspen'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install aspen



## Usage

Before reading this, make sure you know basic Cypher, to the point that you're comfortable writing statements that create and/or query multiple nodes and edges.

### Command-Line Interface

#### Compilation

Compile an Aspen (`.aspen`) file to a Cypher (`.cql`) file.

```
$ aspen compile path/to/file.aspen
```

This will generate a file Cypher file in the same folder, at `path/to/file.cql`.

#### (Roadmap) New / Generate

To create a new Aspen project, run

```
$ aspen new project_name
```

This will generate files and folders to get you started.

TODO: Generate discourses and narratives.


#### (Roadmap) Aspen Notebook

Aspen will eventually ship with a "notebook", a simple web application so you can write Aspen narratives and discourses on the left and see the Cypher or graph visualization on the right. This can help with iteratively building data in Aspen.

### Aspen Tutorial

#### Terminology

There are two important concepts in Aspen: __narratives__ and __discourses__.

A __narrative__ is a description of data that records facts, observations, and perceptions about relationships. For example, in an Aspen file, we'll write `(Matt) [knows] (Brianna)` to describe the relationship between these two people.

A __discourse__ is a way of speaking or writing about a subject. Because Aspen doesn't automatically know what `(Matt) [knows] (Brianna)` means, we have to tell it.

In an Aspen file, the discourse is written at the top, and the narrative is written at the bottom. If you're coming from software development, you can think of the discourse as a sort of configuration that will be used by the rest of the Aspen file.

Here's an example of an Aspen file, with discourse and narrative sections marked:

```
# Discourse
default Person, name

# Narrative
(Matt) [knows] (Brianna).
(Eliza) [knows] (Brianna).
(Matt) [knows] (Eliza).
```

If the concepts of discourse and narrative aren't fully clear right now, that's okay—keep going. The rest of the tutorial should shed light on them. Also, this README was written pretty quickly, and if you have suggestions, please get in touch—your feedback will be well-received and appreciated!

#### Syntax

The simplest case for using Aspen is a simple relationship between two people.

> Matt knows Brianna.

If Matt knows Brianna, we can assume Brianna knows Matt as well.

You can safely guess that:

- "Matt" is a node (entity or object), "knows" is the relationship, and "Brianna" is another node
- "Matt" and "Brianna" are people, so they would have a Person label
- That the relationship is reciprocal

However, Aspen doesn't know any of this automatically! (At least not yet. Someday. Someday...)

So, we need to tell Aspen:

- Whether "Matt", "knows", and "Brianna" are nodes or edges
- What kind of labels to apply to the nodes
- That the relationship "knows" is implicitly reciprocal

To tell Aspen which parts are nodes and which are edges, we borrow the convention of using parentheses `()` to indicate nodes, and square brackets `[]` to indicate edges.

In Aspen, we write:

```
(Matt) [knows] (Brianna). # Narrative
```

This isn't complete. If we ran this, we'd get the following:

```
I don't know what to do with these nodes: (Matt), (Brianna).

What kind of label should I apply to them, and what attribute should I assign the text to?

If these are people, and the text is their name, you can replace (Matt) and (Brianna) with (Person, name: "Matt") and (Person, name: "Brianna").

There's no default set, so if you write at the top of your file "default Person, name", you can keep the nodes the same and it'll assign "Matt" as the name of a Person node, and so forth.
```

So, let's write:

```
default Person, name # Discourse

(Matt) [knows] (Brianna). # Narrative
```

If we ran this, we'd get this Cypher:

```
(Person {name: "Matt"})-[:KNOWS]->(Person {name: "Brianna"})
```

However, we want the relationship "knows" to always be reciprocal.

In Cypher, we'd write "Matt knows Brianna" as:

```
(Person {name: "Matt"})-[:KNOWS]->(Person {name: "Brianna"})
(Person {name: "Matt"})<-[:KNOWS]-(Person {name: "Brianna"})
```

To get this reciprocality, we list all the reciprocal relationships after the keyword   `reciprocal`:

```
default Person, name
reciprocal knows

(Matt) [knows] (Brianna).
```

This gets us the Cypher we want!



### More complicated identifiers

Let's say we have this example.

```
default Person, name

(Matt) [knows] (Brianna)
(Matt Cloyd) [works at] (UMass Boston)
```

This isn't right yet either.

Notice a few things. First, we now have spaces in our identifiers: "Matt Cloyd", "works at", "UMass Boston". Also, UMass Boston isn't a person, it's an institution, organization, employer—whatever your schema, it will be something other than the default node of "Person". So we'll have to tell Aspen about this.

Aspen automatically converts relationships with spaces into the right syntax, so we can rest easy knowing `[works at]` will become `-[:WORKS_AT]->` in our Cypher. (At the moment, all relationships assign left-to-right, unless they are reciprocal relationships.)

Let's first set up some protections to enforce a schema. This will tell Aspen to require us to use the right node labels.

```
protect
  nodes Person, Employer
  edges knows, works at

...
```

Now Aspen will catch us if we assign the wrong node or edge types.

Next, let's add the Employer node to UMass Boston.

```
default Person, name

...
(Matt) [works at] (Employer, name: "UMass Boston")
```

Here, the label is separated by a comma from its attributes. When we start writing attributes in this style, we have to swtich over to using quotes.

However, if we set a default attribute for the Employer node, we can make things a little cleaner.

```
default Person, name
default_attribute Employer, name

...

(Matt) [works at] (Employer, UMass Boston)
```

Let's go over the differences between `default` and `default_attribute`.

The `default` directive will catch any unlabeled nodes, like `(Matt)`, and label them. It will then assign the text inside the parentheses, `"Matt"`, to the attribute given as the default. If the default is `Person, name`, it will create a Person node with name "Matt".

The `default_attribute` will assign the inner text to the given attribute if it's a node of a specific type. For example,

```
default_attribute Employer, name
```


The whole code all together is:

```
default Person, name
default_attribute Employer, name

reciprocal knows

(Matt) [knows] (Brianna)
(Matt) [works at] (Employer, UMass Boston)
```

The Cypher produced generates the reciprocal "knows" relationship, and the one-way employment relationship.

```
MERGE (person-matt:Person { name: "Matt" } )
, (person-brianna:Person { name: "Brianna" } )
, (employer-umass-boston:Employer { name: "UMass Boston" } )

, (person-matt)-[:KNOWS]-(person-brianna)
, (person-matt)-[:WORKS_AT]->(employer-umass-boston)
```

__Note on reciprocal relationships__
In Cypher, the convention for undirected (aka reciprocal or bi-directional) relationships is to write the relationship without an arrowhead, like the above `-[:KNOWS]-`. In Neo4j, all relationships are directional, and when Cypher sees an undirected relationship, it will arbitrarily choose a direction. The reason we don't create two relationships, `<-[:KNOWS]` and `-[:KNOWS]->`, is because when we query for this relationship, we'll use `-[:KNOWS]-`. If we have two `:KNOWS` relationships between nodes, we have unnecessary data duplication.


__Roadmap, this isn't ready yet.__
If you want to assign both a first name and a last name to a Person node.

```
default map |fname, lname|
  Person({ first_name: fname, last_name: lname })
end

default Person, first_name

(Matt Cloyd) [knows] (Brianna)
```

### Attribute Uniqueness

```
default map |fname, lname|
  assign fname, first_name
  assign lname, last_name
end

default Person, first_name

(Matt Cloyd) [knows] (Matt)
```

```
You have a node named "Matt Cloyd" and a node named "Matt"?
Are these the same node, or different nodes? How can I know?
```

### Spaces in relationship names

### Reciprocal Relationships

```
reciprocal:
```

## Background

### Problem Statement

@beechnut, the lead developer of Aspen, attempted to model a simple conflict scenario in Neo4j's language Cypher, but found it took significantly longer than expected. He ran into numerous errors because it wasn't obvious how to construct nodes and edges through simple statements (TODO: Is this even possible).

We assume that most graph data is constructed through various forms and events in web applications. We assume that if the tools existed to support it, easy conversions of narrative statements into graph data would find wide use in a variety of fields.

It is a given that writing Cypher directly is time-consuming and error-prone, especially for beginners. This is not a criticism of Cypher—we love Cypher and think it's extremely-well designed. It is an observation that there's a gap between writing narrative statements and modeling relationships in Cypher. Aspen is attempting to bridge that gap.

### Hypotheses

We believe that graph databases and graph algorithms can provide deep insights into complex systems, and that people would find value in converting simple narrative descriptions into graph data is a worthwhile.

However, we don't know for sure that, if we were to provide this tool, that there would be significant use cases. People are creating graph data in other ways, and it's not clear that there's a need for this narrative-to-graph conversion.

## Contributing

Our dream for Aspen is that it would be able to allow custom grammars defined like Cucumber-tests, where narrative statements could be mapped to custom relationship structures. At the moment, Aspen is nowhere near this level of implicitness or complexity, and it would take a significant team working for a significant amount of time on this.

If you'd like to see Aspen grow, please get in touch, whether you're a developer, user, or potential sponsor. We have ideas on ways to grow Aspen, and we need your help to do so, whatever form that help takes. We'd love to invite a corporate sponsor to help inform and sustain Aspen's growth and development.

## Roadmap

```
[ ] Compile Aspen to Cypher.
  [x] The simplest Aspen, with default, default_attribute, and reciprocal.
  [ ] Short nicknames & attribute uniqueness
  [ ] Custom attribute handling functions
  [ ] Schema and attribute protections
    [ ] Use dry-rb validations or schema to enforce Neo4j/Cypher requirements on tokens, like, must labels be one word capitalized?
  [ ] Implicit relationships
    [ ] Left-to-right
    [ ] Right-to-left
[ ] Live connection between an Aspen web application "Aspen Notebook" and Neo4j graph database instance.
[ ] Use Aspen Notebook to see diffs and publish data in a Neo4j instance.
[ ] Convert Neo4j data to Aspen.
```

### Features

#### Reciprocal relationships

Some relationships are reciprocal—with few exceptions, if two people are friends, it's a two-way relationship.

```
...
reciprocal is friends with
(Matt) [is friends with] (Brianna)
```

Sometimes, we need to mention exceptions, like if someone thinks they're friends with someone else, but the other person doesn't.

```
...
reciprocal is friends with

(Matt) [is friends with | not reciprocal] (Brianna)
# or
(Matt) [is friends with | f] (Brianna)
```

### Features on the Roadmap

We provide two ways to write it, one "not reciprocal" to be extra clear, or "f" for "false", which is shorter to write.

#### Attribute uniqueness

Let's say you reference a person by first and last name, and later refer to that person by last name. Aspen will catch this and ask you to give enough unique attributes to confidently distinguish between the nodes. The only thing worse than messy narrative data is messy graph data.

#### Handling spaces in identifiers (Custom attribute handling functions)

Sometimes you'll want the default attribute on a node to be different, depending on how many attributes are given. For example, you might want to map "First Last" to `first_name` and `last_name` on a given node.

#### Schema protections

To protect against writing the wrong nodes and edges, we can add a `protect` block to allow only certain types of nodes and edges.

```
allow
  nodes Person
  edges knows, works at

# Throws an error because Friend is not an allowed node type.
(Friend, Matt) [knows] (Person, Brianna)

# Throws an error because "loves" is not an allowed relationship type.
(Person, Matt) [loves] (Person, Brianna)
```

To require that any  attributes
require
  Person: first_name
  works at: start_date

#### Implicit relationships

Some relationships naturally imply other relationships. For example, if two people are friends, they must know each other. In this particular case, it might be better for the querier to know that IS_FRIENDS_WITH and KNOWS are synonymous, avoiding data duplication, but whatever, this is a tutorial.

```
implicit
  is friends with -> knows

(Matt) [is friends with] (Brianna)
```

When this is compiled, it will assign the [:KNOWS] relationship before the [:IS_FRIENDS_WITH] relationships. All implicit relationships are run before. I don't know if this matters.

#### Relationships that assign right-to-left

Sometimes, we want to assign relationships right-to-left, `<-[:REL]-`, especially when running implicit relationships.

```
# TODO
```

#### Mapping sentence patterns to Cypher

This example lists two sentences that, if encountered in Cypher will produce the

```
# Discourse
map
  (Person a) donated $(float amt) to (Person b).
  (Person a) gave (Person b) $(float amt).
to
  (<a>)-[:GAVE_DONATION]->(Donation {amount: <amt>})<-[:RECEIVED_DONATION]-(<c>)

# Narrative
Matt donated $20 to Hélène Vincent.
Krista gave Hélène Vincent $30.50.
```

```cql
(Person {name: "Matt"})-[:GAVE_DONATION]->(Donation {amount: 20.0})-[:RECEIVED]->(Person {name: "Hélène Vincent."})
(Person {name: "Krista"})-[:GAVE_DONATION]->(Donation {amount: 30.5})-[:RECEIVED]->(Person {name: "Hélène Vincent."})
```


## Code of Conduct

There's an expectation that people working on this project will be good and kind to each other. The subject matter here is relationships, and anyone who works on this project is expected to have a baseline of healthy relating skills.

Everyone interacting in the Aspen project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/beechnut/aspen/blob/master/CODE_OF_CONDUCT.md).

The full Code of Conduct is available at CODE_OF_CONDUCT.md.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/beechnut/aspen. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/beechnut/aspen/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

