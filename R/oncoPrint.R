
# == title
# Make oncoPrint
#
# == param
# -mat a character matrix which encodes mulitple alterations or a list of matrix for which every matrix contains binary
#      value representing the alteration is present or absent. When it is a list, the names represent alteration types.
#      You can use `unify_mat_list` to make all matrix having same row names and column names.
# -get_type If different alterations are encoded in the matrix, this self-defined function
#           determines how to extract them. Only work when ``mat`` is a matrix.
# -alter_fun a single function or a list of functions which define how to add graphics for different alterations.
#                 If it is a list, the names of the list should cover all alteration types.
# -alter_fun_list deprecated, use ``alter_run`` instead.
# -col a vector of color for which names correspond to alteration types.
# -row_order order of genes. By default it is sorted by frequency of alterations decreasingly.
#                            Set it to ``NULL`` if you don't want to set the order
# -column_order order of samples. By default the order is calculated by the 'memo sort' method which can visualize
#                                 the mutual exclusivity across genes. Set it to ``NULL`` if you don't want to set the order
# -show_pct whether show percent values on the left of the oncoprint
# -pct_gp graphic paramters for percent row annotation
# -pct_digits digits for percent values
# -axis_gp graphic paramters for axes
# -show_row_barplot whether show barplot annotation on rows
# -row_barplot_width width of barplot annotation on rows. It should be a `grid::unit` object
# -remove_empty_columns if there is no alteration in that sample, whether remove it on the heatmap
# -heatmap_legend_param pass to `Heatmap`
# -top_annotation by default the top annotation contains barplots representing frequency of mutations in every sample.
# -top_annotation_height total height of the column annotations on the top.
# -bottom_annotation a `HeatmapAnnotation` object.
# -bottom_annotation_height total height of the column annotations on the bottom.
# -barplot_ignore specific alterations that you don't want to put on the barplots. If you want to really suppress the top barplot
#        set ``top_annotation`` to ``NULL``.
# -row_title title on row.
# -row_title_side will the title be put on the left or right of the heatmap?
# -row_title_gp graphic parameters for drawing text.
# -row_title_rot rotation of row titles. Only 0, 90, 270 are allowed to set.
# -column_title title on column.
# -column_title_side will the title be put on the top or bottom of the heatmap?
# -column_title_gp graphic parameters for drawing text.
# -column_title_rot rotation of column titles. Only 0, 90, 270 are allowed to set.
# -show_row_names whether show row names.
# -row_names_gp graphic parameters for drawing text.
# -show_column_names whether show column names.
# -column_names_gp graphic parameters for drawing text.
# -split a vector or a data frame by which the rows are split. But if ``cluster_rows`` is a clustering object, ``split`` can be a single number
#        indicating rows are to be split according to the split on the tree.
# -gap gap between row-slices if the heatmap is split by rows, should be `grid::unit` object. If it is a vector, the order corresponds
#   to top to bottom in the heatmap
# -combined_name_fun if the heatmap is split by rows, how to make a combined row title for each slice?
#                 The input parameter for this function is a vector which contains level names under each column in ``split``.
# -width the width of the single heatmap, should be a fixed `grid::unit` object. It is used for the layout when the heatmap
#        is appended to a list of heatmaps.
# -... pass to `Heatmap`, so can set ``bottom_annotation`` here.
#
# == details
# The function returns a normal heatmap list and you can add more heatmaps/row annotations to it.
#
# The 'memo sort' method is from https://gist.github.com/armish/564a65ab874a770e2c26 . Thanks to
# B. Arman Aksoy for contributing the code.
#
# The function would be a little bit slow if you plot it in an interactive device because all alterations
# are added through a foo loop.
#
# For more explanation, please go to the vignette.
#
# == value
# A `HeatmapList-class` object which means you can add other heatmaps or row annotations to it.
#
# == author
# Zuguang Gu <z.gu@dkfz.de>
#
oncoPrint = function(mat, get_type = function(x) x,
	alter_fun = alter_fun_list, alter_fun_list = NULL, col, 
	row_order = oncoprint_row_order(),
	column_order = oncoprint_column_order(),
	show_pct = TRUE, pct_gp = row_names_gp, pct_digits = 0,
	axis_gp = gpar(fontsize = 8), 
	show_row_barplot = TRUE, 
	row_barplot_width = unit(2, "cm"),
	remove_empty_columns = FALSE,
	heatmap_legend_param = list(title = "Alterations"),
	top_annotation = HeatmapAnnotation(column_bar = anno_oncoprint_barplot(), 
		annotation_height = unit(2, "cm")),
	top_annotation_height = top_annotation@size,
	bottom_annotation = new("HeatmapAnnotation"),
    bottom_annotation_height = bottom_annotation@size,
    barplot_ignore = NULL,
	row_title = character(0),
    row_title_side = c("left", "right"),
    row_title_gp = gpar(fontsize = 14),
    row_title_rot = switch(row_title_side[1], "left" = 90, "right" = 270),
    column_title = character(0),
    column_title_side = c("top", "bottom"),
    column_title_gp = gpar(fontsize = 14),
    column_title_rot = 0,
    show_row_names = TRUE,
    row_names_gp = gpar(fontsize = 12),
    show_column_names = FALSE,
    column_names_gp = gpar(fontsize = 12),
    split = NULL,
    gap = unit(1, "mm"),
    combined_name_fun = function(x) paste(x, collapse = "/"),
    width = NULL,
	...) {

	if(length(names(list(...))) > 0) {
		if(any(names(list(...)) %in% c("show_column_barplot", "column_barplot_height"))) {
			stop("`show_column_barplot` and `column_barplot_height` is deprecated, please configure `top_annotation` directly.")
		}
	}

	if(!is.null(alter_fun_list)) {
		warning("`alter_fun_list` is deprecated, please `alter_fun` instead.")
	}
	
	# convert mat to mat_list
	if(inherits(mat, "data.frame")) {
		mat = as.matrix(mat)
	}
	if(inherits(mat, "matrix")) {
		all_type = unique(unlist(lapply(mat, get_type)))
		all_type = all_type[!is.na(all_type)]
		all_type = all_type[grepl("\\S", all_type)]

		mat_list = lapply(all_type, function(type) {
			m = sapply(mat, function(x) type %in% get_type(x))
			dim(m) = dim(mat)
			dimnames(m) = dimnames(mat)
			m
		})
		names(mat_list) = all_type
	} else if(inherits(mat, "list")) {
		mat_list = mat

		all_type = names(mat_list)
		mat_list = lapply(mat_list, function(x) {
				if(!is.matrix(x)) {
					stop("Expect a list of matrix (not data frames).")
				}
				oattr = attributes(x)
				x = as.logical(x)
				attributes(x) = oattr
				x
			})

		if(length(unique(sapply(mat_list, nrow))) > 1) {
			stop("All matrix in 'mat_list' should have same number of rows.")
		}

		if(length(unique(sapply(mat_list, ncol))) > 1) {
			stop("All matrix in 'mat_list' should have same number of columns.")
		}
	} else {
		stop("Incorrect type of 'mat'")
	}

	if(missing(alter_fun) && missing(col)) {
		if(length(mat_list) == 1) {
			af = function(x, y, w, h, v) {
				grid.rect(x, y, w, h, gp = gpar(fill = "#CCCCCC", col = NA))
				if(v[1]) grid.rect(x, y, w*0.9, h*0.9, gp = gpar(fill = "red", col = NA))
			}
			col = "red"
		} else if(length(mat_list) == 2) {
			af = function(x, y, w, h, v) {
				grid.rect(x, y, w, h, gp = gpar(fill = "#CCCCCC", col = NA))
				if(v[1]) grid.rect(x, y, w*0.9, h*0.9, gp = gpar(fill = "red", col = NA))
		        if(v[2]) grid.rect(x, y, w*0.9, h*0.4, gp = gpar(fill = "blue", col = NA))
		    }
		    col = c("red", "blue")
		} else {
			stop("`alter_fun` should be specified.")
		}
		names(col) = names(mat_list)
	} else if(is.list(alter_fun)) {

		# validate the list first
		if(is.null(alter_fun$background)) alter_fun$background = function(x, y, w, h) grid.rect(x, y, w, h, gp = gpar(fill = "#CCCCCC", col = NA))
		sdf = setdiff(all_type, names(alter_fun))
		if(length(sdf) > 0) {
			stop(paste0("You should define shape function for: ", paste(sdf, collapse = ", ")))
		}

		alter_fun = alter_fun[unique(c("background", intersect(names(alter_fun), all_type)))]

		af = function(x, y, w, h, v) {
			if(!is.null(alter_fun$background)) alter_fun$background(x, y, w, h)

			alter_fun = alter_fun[names(alter_fun) != "background"]

			if(sum(v)) {
				for(nm in names(alter_fun)) {
					if(v[nm]) alter_fun[[nm]](x, y, w, h)
				}
			}
		}
	} else {
		af = alter_fun
	}

	col = col[intersect(names(col), all_type)]

	# type as the third dimension
	arr = array(FALSE, dim = c(dim(mat_list[[1]]), length(all_type)), dimnames = c(dimnames(mat_list[[1]]), list(all_type)))
	for(i in seq_along(all_type)) {
		arr[, , i] = mat_list[[i]]
	}

	oncoprint_row_order = function() {
		order(rowSums(count_matrix), decreasing = TRUE)
	}

	oncoprint_column_order = function() {
		scoreCol = function(x) {
			score = 0
			for(i in 1:length(x)) {
				if(x[i]) {
					score = score + 2^(length(x)-i*1/x[i])
				}
			}
			return(score)
		}
		scores = apply(count_matrix[row_order, ,drop = FALSE], 2, scoreCol)
		order(scores, decreasing=TRUE)
	}

	count_matrix = apply(arr, c(1, 2), sum)
	if(is.null(row_order)) row_order = seq_len(nrow(count_matrix))
	if(is.null(column_order)) column_order = seq_len(ncol(count_matrix))
	row_order = row_order
	if(is.character(column_order)) {
		column_order = structure(seq_len(dim(arr)[2]), names = dimnames(arr)[[2]])[column_order]
	}
	column_order = column_order
	names(column_order) = as.character(column_order)
	if(remove_empty_columns) {
		l = rowSums(apply(arr, c(2, 3), sum)) > 0
		arr = arr[, l, , drop = FALSE]
		column_order = structure(seq_len(sum(l)), names = which(l))[as.character(intersect(column_order, which(l)))]
	}

	# validate col
	sdf = setdiff(all_type, names(col))
	if(length(sdf) > 0) {
		stop(paste0("You should define colors for:", paste(sdf, collapse = ", ")))
	}

	# for each gene, percent of samples that have alterations
	pct = rowSums(apply(arr, 1:2, any)) / ncol(mat_list[[1]])
	pct = paste0(round(pct * 100, digits = pct_digits), "%")
	ha_pct = rowAnnotation(pct = row_anno_text(pct, just = "right", offset = unit(1, "npc"), gp = pct_gp), width = max_text_width(pct, gp = pct_gp))

	#####################################################################
	# row annotation which is a barplot
	anno_row_bar = function(index, k = NULL, N = NULL) {
		n = length(index)
		count = apply(arr, c(1, 3), sum)[index, , drop = FALSE]
		all_type = all_type[!(colnames(count) %in% barplot_ignore)]
		count = count[, setdiff(colnames(count), barplot_ignore), drop = FALSE]
		max_count = max(rowSums(count))
		pushViewport(viewport(xscale = c(0, max_count*1.1), yscale = c(0.5, n + 0.5)))
		for(i in seq_len(nrow(count))) {
			if(any(count[i, ] > 0)) {
				x = count[i, ]
				x = x[x > 0]
				x2 = cumsum(x)
				type = all_type[count[i, ] > 0]
				# row order is from top to end while coordinate of y is from bottom to top
				# so here we need to use n-i+1
				grid.rect(x2, n-i+1, width = x, height = 0.8, default.units = "native", just = "right", gp = gpar(col = NA, fill = col[type]))
			}
		}
		breaks = grid.pretty(c(0, max_count))
		if(k == 1) {
			grid.xaxis(at = breaks, label = breaks, main = FALSE, gp = axis_gp)
		}
		upViewport()
	}

	ha_row_bar = rowAnnotation(row_bar = anno_row_bar, width = row_barplot_width)

	###################################################################
	# column annotation which is also a barplot
	anno_column_bar = function(index) {
		n = length(index)
		count = apply(arr, c(2, 3), sum)[index, , drop = FALSE]
		all_type = all_type[!(colnames(count) %in% barplot_ignore)]
		count = count[, setdiff(colnames(count), barplot_ignore), drop = FALSE]
		max_count = max(rowSums(count))
		pushViewport(viewport(yscale = c(0, max_count*1.1), xscale = c(0.5, n + 0.5)))
		for(i in seq_len(nrow(count))) {
			if(any(count[i, ] > 0)) {
				y = count[i, ]
				y = y[y > 0]
				y2 = cumsum(y)
				type = all_type[count[i, ] > 0]
				grid.rect(i, y2, height = y, width = 0.8, default.units = "native", just = "top", gp = gpar(col = NA, fill = col[type]))
			}
		}
		breaks = grid.pretty(c(0, max_count))
		grid.yaxis(at = breaks, label = breaks, gp = axis_gp)
		upViewport()
	}

	top_annotation = top_annotation

	#####################################################################
	# the main matrix
	pheudo = c(all_type, rep(NA, nrow(arr)*ncol(arr) - length(all_type)))
	dim(pheudo) = dim(arr)[1:2]
	dimnames(pheudo) = dimnames(arr)[1:2]
	
	if(length(list(...))) {
		if(any(names(list(...)) %in% c("rect_gp", "cluster_rows", "cluster_columns", "cell_fun"))) {
			stop("'rect_gp', 'cluster_rows', 'cluster_columns', 'cell_fun' are not allowed to use in `oncoPrint()`.")
		}
	}

	ht = Heatmap(pheudo, col = col, rect_gp = gpar(type = "none"), 
		cluster_rows = FALSE, cluster_columns = FALSE, row_order = row_order, column_order = column_order,
		cell_fun = function(j, i, x, y, width, height, fill) {
			z = arr[i, j, ]
			names(z) = dimnames(arr)[[3]]
			af(x, y, width, height, z)
		},
		top_annotation = top_annotation,
		top_annotation_height = top_annotation_height,
		bottom_annotation = bottom_annotation,
		bottom_annotation_height = bottom_annotation_height,
		row_title = row_title,
		row_title_side = row_title_side,
		row_title_gp = row_names_gp,
		row_title_rot = row_title_rot,
		column_title = column_title,
		column_title_side = column_title_side,
		column_title_gp = column_title_gp,
		column_title_rot = column_title_rot,
		show_row_names = show_row_names,
		row_names_gp = row_names_gp,
		show_column_names = show_column_names,
		column_names_gp = column_names_gp,
		heatmap_legend_param = heatmap_legend_param, 
		split = split,
		gap = gap,
		combined_name_fun = combined_name_fun,
		width = width,
		...)

	ht@matrix_param$oncoprint = list()
	ht@matrix_param$oncoprint$arr = arr
	ht@matrix_param$oncoprint$barplot_ignore = barplot_ignore
	ht@matrix_param$oncoprint$all_type = all_type
	ht@matrix_param$oncoprint$axis_gp = axis_gp
	ht@matrix_param$oncoprint$col = col

	if(show_pct) {
		ht_list = ha_pct + ht
	} else {
		ht_list = ht
	}

	if(show_row_barplot) {
		ht_list = ht_list + ha_row_bar
	}

	return(ht_list)

}

# == title
# Unify a list of matrix 
#
# == param
# -mat_list a list of matrix, all of them should have dimension names
# -default default values for the newly added rows and columns
#
# == details
# All matrix will be unified to have same row names and column names
#
# == value
# A list of matrix
#
# == author
# Zuguang Gu <z.gu@dkfz.de>
#
unify_mat_list = function(mat_list, default = 0) {
	common_rn = unique(unlist(lapply(mat_list, rownames)))
	common_cn = unique(unlist(lapply(mat_list, colnames)))

	mat_list2 = lapply(seq_along(mat_list), function(i) {
		mat = matrix(default, nrow = length(common_rn), ncol = length(common_cn))
		dimnames(mat) = list(common_rn, common_cn)
		mat[rownames(mat_list[[i]]), colnames(mat_list[[i]])] = mat_list[[i]]
		mat
	})
	names(mat_list2) = names(mat_list)
	return(mat_list2)
}



# == title
# Column barplot annotation for oncoPrint
#
# == details
# This function is only used for column annotation
#
# == author
# Zuguang Gu <z.gu@dkfz.de>
#
anno_oncoprint_barplot = function() {

	function(index) {
		object = get("object", envir = parent.frame(n = 5))
		arr = object@matrix_param$oncoprint$arr
		barplot_ignore = object@matrix_param$oncoprint$barplot_ignore
		all_type = object@matrix_param$oncoprint$all_type
		axis_gp = object@matrix_param$oncoprint$axis_gp
		col = object@matrix_param$oncoprint$col

		n = length(index)
		count = apply(arr, c(2, 3), sum)[index, , drop = FALSE]
		all_type = all_type[!(colnames(count) %in% barplot_ignore)]
		count = count[, setdiff(colnames(count), barplot_ignore), drop = FALSE]
		max_count = max(rowSums(count))
		pushViewport(viewport(yscale = c(0, max_count*1.1), xscale = c(0.5, n + 0.5)))
		for(i in seq_len(nrow(count))) {
			if(any(count[i, ] > 0)) {
				y = count[i, ]
				y = y[y > 0]
				y2 = cumsum(y)
				type = all_type[count[i, ] > 0]
				grid.rect(i, y2, height = y, width = 0.8, default.units = "native", just = "top", gp = gpar(col = NA, fill = col[type]))
			}
		}
		breaks = grid.pretty(c(0, max_count))
		grid.yaxis(at = breaks, label = breaks, gp = axis_gp)
		upViewport()
	}
}


