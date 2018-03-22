{% if page.copyright %}
  <script src="//cdn.bootcss.com/clipboard.js/1.5.10/clipboard.min.js"></script>
<script src="https://cdn.bootcss.com/jquery/2.0.0/jquery.min.js"></script>
  <script src="https://unpkg.com/sweetalert/dist/sweetalert.min.js"></script>
  <div class="my_post_copyright">
  <ul class="post-copyright">
    {% if page.original %}
      <li class="post-copyright-author">
          <strong>{{ __('post.copyright.author') + __('symbol.colon') }}</strong>
          {{ post.author | default(config.author) }}
      </li>
      <li class="post-copyright-link">
        <strong>{{ __('post.copyright.link') + __('symbol.colon') }}</strong>
        <a href="{{ url_for(page.path) }}" title="{{ page.title }}">{{ page.permalink }}</a>
        <span class="copy-path"  title="点击复制文章链接"><i class="fa fa-clipboard" data-clipboard-text="{{ page.permalink }}"  aria-label="复制成功！"></i></span>
      </li>
      <li class="post-copyright-date">
          <strong>发布时间{{ __('symbol.colon') }}</strong>
          {{ page.date.format("YYYY年MM月DD日 - HH:MM") }}
      </li>
      <li class="post-copyright-update">
          <strong>更新时间{{ __('symbol.colon') }}</strong>
          {{ page.updated.format("YYYY年MM月DD日 - HH:MM") }}
      </li>
      <li class="post-copyright-license">
          <strong>{{ __('post.copyright.license_title') + __('symbol.colon') }} </strong>
          {{ __('post.copyright.license_content', theme.post_copyright.license_url, theme.post_copyright.license) }}
      </li>
    {% else %}
      <li class="post-copyright-src-author">
          <strong>原文作者{{ __('symbol.colon') }}</strong>
          {% if page.authorship %}
            {{ page.authorship }}
          {% else %}
            未知
          {% endif  %}
      </li>
      <li class="post-copyright-update">
        <strong>原文链接{{ __('symbol.colon') }}</strong>
        {% if page.srcpath %}
          <a href="{{ url_for(page.srcpath) }}" title="{{ page.title }}">{{ page.permalink }}</a>
          <span class="copy-path"  title="点击复制文章链接"><i class="fa fa-clipboard" data-clipboard-text="{{ page.permalink }}"  aria-label="复制成功！"></i></span>
        {% else %}
          未知
        {% endif  %}

        {% if page.explain %}
          <li class="post-copyright-explain">
              <strong>补充说明{{ __('symbol.colon') }}</strong>
              {{ page.explain }}
          </li>
        {% endif  %}
        <li class="post-copyright-date">
              <strong>发布时间{{ __('symbol.colon') }}</strong>
              {{ page.date.format("YYYY年MM月DD日 - HH:MM") }}
          </li>
          <li class="post-copyright-update">
              <strong>更新时间{{ __('symbol.colon') }}</strong>
              {{ page.updated.format("YYYY年MM月DD日 - HH:MM") }}
          </li>
      </li>
    {% endif  %}
  </ul>
  <script>
    var clipboard = new Clipboard('.fa-clipboard');
      $(".fa-clipboard").click(function(){
      clipboard.on('success', function(){
        swal({
          title: "",
          text: '复制成功',
          icon: "success",
          showConfirmButton: true
          });
        });
    });
  </script>
{% endif %}

