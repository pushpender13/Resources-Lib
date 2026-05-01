import Component from "@glimmer/component";

export default class CategoryNode extends Component {
  get topics() {
    const map = this.args.topicsMap || {};
    return map[this.args.category.id] || [];
  }

  get visibleTopics() {
    let topics = this.topics;
    const query = this.args.searchQuery?.toLowerCase();
    if (query) {
      topics = topics.filter((t) => t.title.toLowerCase().includes(query));
    }
    return topics.slice(0, this.args.maxTopics || 5);
  }

  get hasMoreTopics() {
    return this.topics.length > (this.args.maxTopics || 5);
  }

  get subcategories() {
    return this.args.category.subcategories || [];
  }

  get categoryUrl() {
    const cat = this.args.category;
    return `/c/${cat.slug}/${cat.id}`;
  }

  get hasContent() {
    return this.visibleTopics.length > 0 || this.subcategories.length > 0;
  }

  <template>
    <div class="category-node">
      <div class="category-node__header">
        <span class="category-node__color" style="background-color: #{{@category.color}};"></span>
        <h2 class="category-node__name">{{@category.name}}</h2>
      </div>

      {{#if this.subcategories.length}}
        <div class="category-node__children">
          {{#each this.subcategories as |subCat|}}
            <CategoryNode
              @category={{subCat}}
              @topicsMap={{@topicsMap}}
              @searchQuery={{@searchQuery}}
              @maxTopics={{@maxTopics}}
            />
          {{/each}}
        </div>
      {{else}}
        {{#if this.visibleTopics.length}}
          <ul class="category-node__topics">
            {{#each this.visibleTopics as |topic|}}
              <li class="category-node__topic">
                <a href="/t/{{topic.slug}}/{{topic.id}}" class="category-node__topic-link">
                  {{topic.title}}
                </a>
              </li>
            {{/each}}
          </ul>

          {{#if this.hasMoreTopics}}
            <a href={{this.categoryUrl}} class="category-node__more-link">
              More...
            </a>
          {{/if}}
        {{/if}}
      {{/if}}
    </div>
  </template>
}
