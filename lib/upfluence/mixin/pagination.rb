module Upfluence
  module Mixin
    module Pagination
      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 12

      def paginated_model
        raise NotImplementedError
      end

      def paginated_entities
        @paginated_entities ||= paginated_model.limit(per_page).offset(
          (page - 1) * per_page
        ).to_a
      end

      def paginated_entities=(v)
        @paginated_entities = v
      end

      def paginated_total
        paginated_model.count
      end

      def page
        [params[:page].to_i, DEFAULT_PAGE].max
      end

      def per_page
        [
          params[:per_page].to_i,
          methods.include?(:default_per_page) ? default_per_page : DEFAULT_PER_PAGE
        ].max
      end

      def respond_with_pagination(args = {})
        respond_with(
          args[:payload] || paginated_entities,
          args.merge(
            meta: {
              total: paginated_total,
              total_pages: (paginated_total.to_f / per_page.to_f).ceil
            }
          ) { |_, x, y| x.merge(y) }
        )
      end
    end
  end
end
