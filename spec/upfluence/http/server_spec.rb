require 'spec_helper'
require 'rack/mock'
require 'upfluence/http/server'

RSpec.describe Upfluence::HTTP::Server do
  def build_server(**opts, &block)
    block ||= proc { run ->(_env) { [200, {}, ["app\n"]] } }

    described_class.new(
      prometheus_endpoint: false,
      instrumentations:    [],
      **opts,
      &block
    )
  end

  def mock_request(builder, path, method: :get)
    Rack::MockRequest.new(builder).send(method, path)
  end

  describe 'without admin_port' do
    let(:server) { build_server(admin_port: nil) }
    let(:builder) { server.instance_variable_get(:@production_builder) }

    it 'does not create an admin builder' do
      expect(server.instance_variable_get(:@admin_builder)).to be_nil
    end

    it 'serves /healthcheck' do
      resp = mock_request(builder, '/healthcheck')

      expect(resp.status).to eq(200)
      expect(resp.body).to eq("ok\n")
    end

    it 'serves the app' do
      resp = mock_request(builder, '/')

      expect(resp.status).to eq(200)
      expect(resp.body).to eq("app\n")
    end

    context 'with debug enabled' do
      let(:server) { build_server(admin_port: nil, debug: '1') }

      it 'serves /debug on the production builder' do
        resp = mock_request(builder, '/debug/profile')

        expect(resp.body).to eq('No profile available')
      end
    end

    context 'with debug disabled' do
      it 'does not mount /debug' do
        resp = mock_request(builder, '/debug/start')

        expect(resp.body).to eq("app\n")
      end
    end
  end

  describe 'with admin_port' do
    let(:server) { build_server(admin_port: 9394, debug: debug) }
    let(:production) { server.instance_variable_get(:@production_builder) }
    let(:admin) { server.instance_variable_get(:@admin_builder) }

    context 'with debug disabled' do
      let(:debug) { nil }

      it 'serves /healthcheck on both builders' do
        expect(mock_request(production, '/healthcheck').status).to eq(200)
        expect(mock_request(admin, '/healthcheck').status).to eq(200)
      end

      it 'serves the app on the production builder' do
        resp = mock_request(production, '/')

        expect(resp.status).to eq(200)
        expect(resp.body).to eq("app\n")
      end

      it 'does not mount /debug on either builder' do
        expect(mock_request(production, '/debug/start').body).to eq("app\n")
        expect(mock_request(admin, '/debug/start').status).to eq(404)
      end
    end

    context 'with debug enabled' do
      let(:debug) { '1' }

      it 'serves /debug only on the admin builder' do
        expect(mock_request(admin, '/debug/profile').body).to eq('No profile available')
        expect(mock_request(production, '/debug/profile').body).to eq("app\n")
      end
    end
  end

  describe 'custom healthcheck endpoint' do
    let(:custom) { ->(_env) { [200, {}, ["custom\n"]] } }
    let(:server) { build_server(healthcheck_endpoint: custom) }
    let(:builder) { server.instance_variable_get(:@production_builder) }

    it 'uses the custom endpoint' do
      resp = mock_request(builder, '/healthcheck')

      expect(resp.status).to eq(200)
      expect(resp.body).to eq("custom\n")
    end
  end
end
