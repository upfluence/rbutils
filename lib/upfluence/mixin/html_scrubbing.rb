require 'loofah'

module Upfluence
  module Mixin
    module HTMLScrubbing
      def scrub_params(params, *keys)
        keys.reduce(params) do |vs, key|
          if vs.key? key
            vs.merge(key => scrub_value(vs[key]))
          else
            vs
          end
        end
      end

      private

      def scrub_value(value)
        return nil unless value.is_a? String

        Loofah.fragment(value).scrub!(:prune).to_s
      end
    end
  end
end
