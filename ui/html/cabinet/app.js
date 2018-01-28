
var $$ = initFramework('cabinet');

$$.stateChangeCallback(function(active)
{
	if (active) {
		$("#formLogin").hide();
		$(".logged-in").show();
		$$.page("index");
	} else {
		$("#page").html("");
		$("#loginError").hide();
		$(".logged-in").hide();
		$("#formLogin").show();
	}
});

function init() {
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

$(init());
