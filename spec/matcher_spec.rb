require 'aspen'

describe Aspen::Matcher do

  # let(:context) { Aspen::Discourse.new("default Person, name") }

  context "stepwise" do

    let(:statement) { "I have (numeric apple_count) apples." }
    let(:template) { "(:Person { name: \"me\", apple_count: {{apple_count}} })" }
    let(:aspen) { "I have 1,000 apples." }

    it "renders a type-based pattern" do
      matcher = Aspen::Matcher.new(statement, template)
      pattern = /^I have (?-mix:(?<apple_count>[\d,]+\.?\d+)) apples\.?$/

      expect(matcher.pattern).to eq(pattern)
      expect(matcher.match?(aspen)).to be true
      expect(matcher.matches!(aspen)).to eq({ "apple_count" => [[:SEGMENT_MATCH_NUMERIC], "1,000"] })
    end

  end

  context "numeric values" do

    let(:numeric_statement) { "I have (numeric apple_count) apples." }
    let(:numeric_cypher_template)  { "(:Person { name: \"Matt\", apples: {{apple_count}} })" }

    context "without commas" do
      let(:aspen)  { "I have 10 apples." }
      let(:subject) {
        Aspen::Matcher.new(numeric_statement, numeric_cypher_template)
      }

      it "returns matches" do
        expect(subject.matches!(aspen)).to eq({ "apple_count" => [[:SEGMENT_MATCH_NUMERIC], "10"] })
      end
    end

    context "with commas" do
      let(:aspen)  { "I have 1,000 apples." }
      let(:subject) {
        Aspen::Matcher.new(numeric_statement, numeric_cypher_template)
      }

      it "handles commas gracefully" do
        expect(subject.matches!(aspen)).to eq({ "apple_count" => [[:SEGMENT_MATCH_NUMERIC], "1,000"] })
      end
    end
  end # numeric

  context "string values" do

    let(:string_map) { "I have a dog named (string dog_name)." }
    let(:string_cypher_template)  { "(:Person { name: \"Matt\" })-[:OWNS]->(:Pet { type: \"dog\", name: {{{dog_name}}} })" }
    let(:aspen)  { "I have a dog named \"Fido\"." }

    let(:subject) {
      Aspen::Matcher.new(string_map, string_cypher_template)
    }

    it "returns matches" do
      expect(subject.matches!(aspen)).to eq({ "dog_name" => [[:SEGMENT_MATCH_STRING], "\"Fido\""] })
    end
  end # string

  context "mixed values" do

    let(:mixed_map) { "(Person a) gave (Person b) $(numeric amt)." }
    let(:mixed_cypher_template) { "{{{a}}}-[:GAVE_DONATION]->(:Donation { amount: {{amt}} })<-[:RECEIVED_DONATION]-{{{b}}}" }
    let(:aspen) { "Matt gave Hélène $2,000." }

    let(:subject) {
      Aspen::Matcher.new(mixed_map, mixed_cypher_template)
    }

    it "returns matches" do
      expect(subject.matches!(aspen)).to eq({
        "a"   => [[:SEGMENT_MATCH_NODE, "Person"], "Matt"],
        "amt" => [[:SEGMENT_MATCH_NUMERIC], "2,000"],
        "b"   => [[:SEGMENT_MATCH_NODE, "Person"], "Hélène"],
      })
    end
  end # mixed
end
