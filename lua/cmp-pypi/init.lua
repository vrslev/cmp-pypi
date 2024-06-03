local source = {}

---@return string
function source:get_debug_name()
	return "pypi"
end

---@return boolean
function source:is_available()
	local filename = vim.fn.expand("%:t")
	return filename == "pyproject.toml"
end

---@return string
function source:get_keyword_pattern()
	return [[\k\+]]
end

---@return string[]
function source:get_trigger_characters()
	return { "=", ".", "^", "~" }
end

---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse|nil)
function source:complete(params, callback)
	local core = require("cmp-pypi.core")
	if not core.should_complete() then
		return callback()
	end

	local line = params.context.cursor_before_line

	local name, _ = string.match(line, '([^"]+)==([^"=]*)$')

	if not name then
		name, _ = string.match(line, '^([^= ]+)%s?=%s?"([^"]*)$')

		if not name then
			return callback()
		end
	end

	vim.schedule(function()
		local result = core.complete(name)
		callback(result)
	end)
end

---@param completion_item lsp.CompletionItem
---@param callback function
function source:resolve(completion_item, callback)
	callback(completion_item)
end

---@param completion_item lsp.CompletionItem
---@param callback function
function source:execute(completion_item, callback)
	callback(completion_item)
end

return source
