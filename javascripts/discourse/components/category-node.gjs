import Component from "@glimmer/component";
import { hbs } from "ember-cli-htmlbars";

export default class CategoryNode extends Component {
  static template = hbs`
    <div class="category-block">
      <h3>{{@cat.name}}</h3>

      {{#if @topics[@cat.id]}}
        <ul>
          {{#each (call @filter @topics[@cat.id]) as |topic|}}
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
  `;
}
