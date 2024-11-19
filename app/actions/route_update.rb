module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        if message.requested?(:options)
          route.options = if message.options.nil?
                            route.options
                          elsif route.options.nil?
                            message.options
                          else
                            route.options.merge(message.options)
                          end
        end

        # remove nil values from options
        route.options = route.options.compact if route.options

        route.save
        MetadataUpdate.update(route, message)
      end

      route
    end
  end
end
