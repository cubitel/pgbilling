
var $$ = initFramework('cabinet');

function onHashChange()
{
    var hash = location.hash || "#!/index";
    var re = /#!\/([-_0-9A-Za-z\/]+)(\:(.+))?/;
    var match = re.exec(hash);

    if (match === null) return;

    hash = match[1];
    params = match[3];
    $$.page(hash, params);
}

$$.stateChangeCallback(function(active)
{
	if (active) {
		$("#loginDialog").modal('hide');
		$(".logged-in").show();
		$(window).bind("hashchange", onHashChange);
		onHashChange();
		sidebar.refresh();
	} else {
		$("#page").html("");
		$("#sidebar").html("");
		$("#loginError").hide();
		$(".logged-in").hide();
		$("#inputLogin").val('');
		$("#inputPassword").val('');
		$("#loginDialog").modal('show');
		$(window).unbind("hashchange");
	}
});

var sidebar = (function () {
	var obj = {};

	obj.user = {};

	obj.refresh = async function () {
		var sql = await $$.cmd('select', {table: 'user_info'});
		obj.user = sql.rows[0];
		$$.render('#sidebar', '#tmpl-sidebar', {user: obj.user, config: config});
	};

	return obj;
})();

function init() {
	$('.modal').on('shown.bs.modal', function() {
		$(this).find('[autofocus]').focus();
	});

	$("#loginDialog").modal({keyboard: false, backdrop: 'static'});

	$(document).on('submit', '#formLogin', function(e) {
		e.preventDefault();
		(async function() {
			$("#loginError").hide();

			var login = $("#inputLogin").val();
			var password = $("#inputPassword").val();

			try {
				await $$.login(login, password);
			} catch (err) {
				$("#loginError").text(err.message).show();
			}
		})();
		return false;
	});
};

$(window).on('load', init);
