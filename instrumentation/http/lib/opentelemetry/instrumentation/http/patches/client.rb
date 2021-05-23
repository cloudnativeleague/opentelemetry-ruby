# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry/common/http/request_attributes'

module OpenTelemetry
  module Instrumentation
    module HTTP
      module Patches
        # Module to prepend to HTTP::Client for instrumentation
        module Client
          def perform(req, options)
            uri = req.uri
            request_method = req.verb.to_s.upcase

            attributes = OpenTelemetry::Common::HTTP::RequestAttributes.from_request(request_method, uri, config)
                                                                       .merge(OpenTelemetry::Common::HTTP::ClientContext.attributes)

            tracer.in_span("HTTP #{request_method}", attributes: attributes, kind: :client) do |span|
              OpenTelemetry.propagation.inject(req.headers)
              super.tap do |response|
                annotate_span_with_response!(span, response)
              end
            end
          end

          private

          def annotate_span_with_response!(span, response)
            return unless response&.status

            status_code = response.status.to_i
            span.set_attribute('http.status_code', status_code)
            span.status = OpenTelemetry::Trace::Status.http_to_status(status_code)
          end

          def tracer
            HTTP::Instrumentation.instance.tracer
          end

          def config
            HTTP::Instrumentation.instance.config
          end
        end
      end
    end
  end
end
