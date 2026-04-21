-- machinations_core.lua
local M = {}

M.NODE_TYPE = {
	SOURCE = "source",       -- 产出节点：无限产生资源
	DRAIN = "drain",         -- 消耗节点：无限吞噬资源
	POOL = "pool",           -- 资源池：存储资源
	CONVERTER = "converter", -- 转换器：满足输入条件后，将其转化为输出
	GATE = "gate"            -- 网关：根据条件或概率分配资源（基础版暂时简单处理）
}

function M.create_simulation()
	local sim = {
		nodes = {},
		links = {},
		step_count = 0
	}

	-- 添加节点
	function sim:add_node(id, type, initial_value)
		self.nodes[id] = {
			id = id,
			type = type,
			value = initial_value or 0,  -- 当前资源量
			next_value = initial_value or 0 -- 用于双缓冲计算，确保同步步进
		}
		return self.nodes[id]
	end

	-- 添加连线 (rate: 每次Step流动的资源量)
	function sim:add_link(from_id, to_id, rate, condition_func)
		table.insert(self.links, {
			from = from_id,
			to = to_id,
			rate = rate,
			condition = condition_func -- 可选的条件函数，如: function(sim) return sim.nodes["gold"].value > 10 end
		})
	end

	-- 运行一次步进 (Step)
	function sim:step()
		self.step_count = self.step_count + 1

		-- 1. 准备计算：同步当前状态到下一帧
		for id, node in pairs(self.nodes) do
			node.next_value = node.value
		end

		-- 2. 计算资源流动
		for _, link in ipairs(self.links) do
			-- 检查条件是否满足
			if link.condition == nil or link.condition(self) then
				local from_node = self.nodes[link.from]
				local to_node = self.nodes[link.to]

				local amount_to_move = link.rate

				-- 判断来源节点类型
				if from_node.type == M.NODE_TYPE.POOL or from_node.type == M.NODE_TYPE.CONVERTER then
					-- 只能转移拥有的资源
					amount_to_move = math.min(amount_to_move, from_node.value)
					from_node.next_value = from_node.next_value - amount_to_move
				elseif from_node.type == M.NODE_TYPE.SOURCE then
					-- Source有无限资源，所以直接流出 full rate
				end

				-- 判断目标节点类型
				if amount_to_move > 0 then
					if to_node.type == M.NODE_TYPE.POOL then
						to_node.next_value = to_node.next_value + amount_to_move
					elseif to_node.type == M.NODE_TYPE.CONVERTER then
						-- 转换器接收资源，在基础实现中可视为临时Pool
						to_node.next_value = to_node.next_value + amount_to_move
					elseif to_node.type == M.NODE_TYPE.DRAIN then
						-- Drain 直接吞噬，不做任何增加
					end
				end
			end
		end

		-- 3. 处理转换器 (Converter) 的转换逻辑
		-- 假设Converter每积攒 X 个输入，就转化为 Y 个输出（此处简化为1:1，可通过扩充属性实现复杂比例）
		for id, node in pairs(self.nodes) do
			if node.type == M.NODE_TYPE.CONVERTER then
				-- 极简版逻辑：只要转换器里有资源，就强制流出。复杂转换逻辑可以在这里拓展。
			end
		end

		-- 4. 应用修改，完成步进
		for id, node in pairs(self.nodes) do
			node.value = node.next_value
		end
	end

	-- 打印当前状态（用于调试）
	function sim:print_state()
		print("--- Step: " .. self.step_count .. " ---")
		for id, node in pairs(self.nodes) do
			print(string.format("Node [%s] (%s): %d", node.id, node.type, node.value))
		end
	end

	return sim
end

return M