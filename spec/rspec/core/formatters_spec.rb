require 'pathname'

module RSpec::Core::Formatters
  RSpec.describe Loader do

    let(:output)   { StringIO.new }
    let(:reporter) { instance_double "Reporter", :register_listener => nil }
    let(:loader)   { Loader.new reporter }

    describe "#add(formatter)" do
      let(:path) { File.join(Dir.tmpdir, 'output.txt') }

      it "adds to the list of formatters" do
        loader.add :documentation, output
        expect(loader.formatters.first).to be_an_instance_of(DocumentationFormatter)
      end

      it "finds a formatter by name (w/ Symbol)" do
        loader.add :documentation, output
        expect(loader.formatters.first).to be_an_instance_of(DocumentationFormatter)
      end

      it "finds a formatter by name (w/ String)" do
        loader.add 'documentation', output
        expect(loader.formatters.first).to be_an_instance_of(DocumentationFormatter)
      end

      it "finds a formatter by class" do
        formatter_class = Class.new(BaseTextFormatter)
        Loader.formatters[formatter_class] = []
        loader.add formatter_class, output
        expect(loader.formatters.first).to be_an_instance_of(formatter_class)
      end

      it "finds a formatter by class name" do
        stub_const("CustomFormatter", Class.new(BaseFormatter))
        Loader.formatters[CustomFormatter] = []
        loader.add "CustomFormatter", output
        expect(loader.formatters.first).to be_an_instance_of(CustomFormatter)
      end

      context "when a legacy formatter is added with RSpec::LegacyFormatters" do
        formatter_class = Struct.new(:output)
        let(:formatter) { double "formatter", :notifications => notifications }
        let(:notifications) { [:a, :b, :c] }

        before do
          class_double("RSpec::LegacyFormatters", :load_formatter => formatter).as_stubbed_const
        end

        it "loads formatters from the external gem" do
          loader.add formatter_class, output
          expect(loader.formatters).to eq [formatter]
        end

        it "subscribes the formatter to the notifications the adaptor implements" do
          expect(reporter).to receive(:register_listener).with(formatter, *notifications)
          loader.add formatter_class, output
        end
      end

      context "when a legacy formatter is added without RSpec::LegacyFormatters" do
        formatter_class = Struct.new(:output)

        before do
          allow_deprecation
        end

        it "issues a deprecation" do
          expect_warn_deprecation_with_call_site(__FILE__, __LINE__ + 2,
            /The #{formatter_class} formatter uses the deprecated formatter interface/)
          loader.add formatter_class, output
        end
      end

      it "finds a formatter by class fully qualified name" do
        stub_const("RSpec::CustomFormatter", (Class.new(BaseFormatter)))
        Loader.formatters[RSpec::CustomFormatter] = []
        loader.add "RSpec::CustomFormatter", output
        expect(loader.formatters.first).to be_an_instance_of(RSpec::CustomFormatter)
      end

      it "requires a formatter file based on its fully qualified name" do
        expect(loader).to receive(:require).with('rspec/custom_formatter') do
          stub_const("RSpec::CustomFormatter", (Class.new(BaseFormatter)))
          Loader.formatters[RSpec::CustomFormatter] = []
        end
        loader.add "RSpec::CustomFormatter", output
        expect(loader.formatters.first).to be_an_instance_of(RSpec::CustomFormatter)
      end

      it "raises NameError if class is unresolvable" do
        expect(loader).to receive(:require).with('rspec/custom_formatter3')
        expect { loader.add "RSpec::CustomFormatter3", output }.to raise_error(NameError)
      end

      it "raises ArgumentError if formatter is unknown" do
        expect { loader.add :progresss, output }.to raise_error(ArgumentError)
      end

      context "with a 2nd arg defining the output" do
        it "creates a file at that path and sets it as the output" do
          loader.add('doc', path)
          expect(loader.formatters.first.output).to be_a(File)
          expect(loader.formatters.first.output.path).to eq(path)
        end

        it "accepts Pathname objects for file paths" do
          pathname = Pathname.new(path)
          loader.add('doc', pathname)
          expect(loader.formatters.first.output).to be_a(File)
          expect(loader.formatters.first.output.path).to eq(path)
        end
      end

      context "when a duplicate formatter exists" do
        before { loader.add :documentation, output }

        it "doesn't add the formatter for the same output target" do
          expect {
            loader.add :documentation, output
          }.not_to change { loader.formatters.length }
        end

        it "adds the formatter for different output targets" do
          expect {
            loader.add :documentation, path
          }.to change { loader.formatters.length }
        end
      end
    end

    describe "#setup_default", "with profiling enabled" do
      let(:setup_default) { loader.setup_default output, output }

      before do
        allow(RSpec.configuration).to receive(:profile_examples?) { true }
      end

      context "without an existing profile formatter" do
        it "will add the profile formatter" do
          allow(reporter).to receive(:registered_listeners).with(:dump_profile) { [] }
          setup_default
          expect(loader.formatters.last).to be_a ::RSpec::Core::Formatters::ProfileFormatter
        end
      end

      context "when a formatter that implement #dump_profile is added" do
        it "wont add the profile formatter" do
          allow(reporter).to receive(:registered_listeners).with(:dump_profile) { [:json] }
          setup_default
          expect(
            loader.formatters.map(&:class)
          ).to_not include ::RSpec::Core::Formatters::ProfileFormatter
        end
      end
    end
  end
end
