import Component from "@glimmer/component";

export default class CategoryNode extends Component {
  <template>
    <div class="category-block">
      <h3>{{@cat.name}}</h3>

      {{#if (get @topics @cat.id)}}
        <ul>
          {{#each (this.filter (get @topics @cat.id)) as |topic|}}
            <li>
              <a href="/t/{{topic.slug}}/{{topic.id}}">
                {{topic.title}}
              </a>
            </li>
          {{/each}}
        </ul>

        <a href="/c/{{@cat.slug}}">More</a>
      {{/if}}

      {{#if @cat.children.length}}
        <div class="children">
          {{#each @cat.children as |child|}}
            <CategoryNode
              @cat={{child}}
              @topics={{@topics}}
              @filter={{@filter}}
            />
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>

  filter(topics) {
    return this.args.filter ? this.args.filter(topics) : topics;
  }
}
