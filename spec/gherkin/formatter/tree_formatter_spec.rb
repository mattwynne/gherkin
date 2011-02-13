require 'spec_helper'
require 'gherkin/formatter/tree_formatter'

module Gherkin
  module Formatter
    describe TreeFormatter do
      let(:receiver) do 
        Class.new do
          attr_accessor :features
          
          def initialize
            self.features = []
          end
          
          def feature(feature)
            features << feature
          end
        end.new
      end
      let(:feature)   { receiver.features.first }
      let(:formatter) { TreeFormatter.new(receiver) }
      let(:parser)    { Gherkin::Parser::Parser.new(formatter, true, "root", true) }
      
      before(:each) do
        parser.parse(gherkin, "test.feature", 0)
      end
      
      let(:gherkin) do
        %{
Feature: A
  Background: X
  Scenario: Y
    Given 1
    When 2
  Scenario Outline: YY
    Given 10
    Examples: YY1
      | a |
    Examples: YY2
      | a |
  Scenario: Z

}
      end
      
      it "collects the background" do
        feature.background.name.should == "X"
      end
      
      it "collects up scenarios" do
        feature.scenarios.length.should == 2
        feature.scenarios.first.name.should == "Y"
        feature.scenarios.first.steps.first.name.should == '1'
        feature.scenarios.first.steps.last.name.should == '2'
        feature.scenarios.last.name.should == "Z"
      end
      
      it "collects the scenario outline" do
        feature.scenario_outlines.first.name.should == 'YY'
        feature.scenario_outlines.first.steps.first.name.should == '10'
        feature.scenario_outlines.first.examples.first.name.should == 'YY1'
        feature.scenario_outlines.first.examples.last.name.should == 'YY2'
      end
    end
  end
end